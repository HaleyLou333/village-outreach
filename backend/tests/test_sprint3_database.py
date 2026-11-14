"""PostgreSQL constraints, migration reversibility and competing writers."""

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

import pytest
from alembic import command
from fastapi import HTTPException
from sqlalchemy import func, inspect, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import HelpRequest, Message, Offer, User
from app.schemas.messages import MessageCreate
from app.schemas.offers import OfferCreate
from app.schemas.requests import RequestCreate, RequestUpdate
from app.services.messages import create_message
from app.services.offers import accept_offer, create_offer
from app.services.requests import create_request, update_request
from tests.conftest import migration_config
from tests.test_request_api import payload

pytestmark = pytest.mark.database


@pytest.fixture
def committed_graph(db_engine):
    """Committed records for independent workers; cleanup only this fixture's data."""
    ids = [uuid4() for _ in range(4)]
    rid = None
    try:
        with Session(db_engine) as session:
            session.add_all(
                [
                    User(
                        id=uid,
                        supabase_uid=uuid4(),
                        email=f"{uid}@example.invalid",
                        display_name="Concurrency",
                    )
                    for uid in ids
                ]
            )
            session.commit()
            request, _ = create_request(session, ids[0], RequestCreate(**payload()), str(uuid4()))
            rid = request.id
        yield ids, rid
    finally:
        with db_engine.begin() as connection:
            if rid is not None:
                for model in (Message, Offer):
                    connection.execute(model.__table__.delete().where(model.request_id == rid))
                connection.execute(HelpRequest.__table__.delete().where(HelpRequest.id == rid))
            connection.execute(User.__table__.delete().where(User.id.in_(ids)))


def run_race(db_engine, *operations):
    barrier = Barrier(len(operations))

    def run(operation):
        with Session(db_engine) as session:
            session.execute(text("SET LOCAL lock_timeout = '5s'"))
            barrier.wait(timeout=5)
            try:
                operation(session)
                return 200
            except HTTPException as error:
                session.rollback()
                return error.status_code

    with ThreadPoolExecutor(max_workers=len(operations)) as pool:
        return list(pool.map(run, operations))


def setup_offers(db_engine, ids, rid):
    with Session(db_engine) as session:
        return [
            create_offer(session, uid, OfferCreate(request_id=rid, message="Help"), str(uuid4()))[0]
            for uid in ids[1:3]
        ]


def test_competing_acceptance_selects_exactly_one_helper(db_engine, committed_graph):
    ids, rid = committed_graph
    offers = setup_offers(db_engine, ids, rid)
    results = run_race(
        db_engine, *(lambda s, oid=o.id: accept_offer(s, oid, ids[0]) for o in offers)
    )
    assert sorted(results) == [200, 409]
    with Session(db_engine) as session:
        assert sorted(session.scalars(select(Offer.status).where(Offer.request_id == rid))) == [
            "accepted",
            "declined",
        ]


def test_competing_same_acceptance_is_safe_retry(db_engine, committed_graph):
    ids, rid = committed_graph
    offers = setup_offers(db_engine, ids, rid)

    def action(session):
        return accept_offer(session, offers[0].id, ids[0])

    assert run_race(db_engine, action, action) == [200, 200]


@pytest.mark.parametrize("kind", ["offer", "message", "accept"])
def test_closure_serializes_with_new_writes(db_engine, committed_graph, kind):
    ids, rid = committed_graph
    offers = setup_offers(db_engine, ids, rid)
    if kind == "message":
        with Session(db_engine) as session:
            accept_offer(session, offers[0].id, ids[0])

    def write(session):
        if kind == "offer":
            create_offer(session, ids[3], OfferCreate(request_id=rid, message="Help"), str(uuid4()))
        elif kind == "message":
            create_message(
                session,
                ids[0],
                MessageCreate(request_id=rid, receiver_id=ids[1], body="Hi"),
                str(uuid4()),
            )
        else:
            accept_offer(session, offers[0].id, ids[0])

    results = run_race(
        db_engine,
        lambda s: update_request(s, rid, ids[0], RequestUpdate(status="completed")),
        write,
    )
    assert results[0] == 200 and results[1] in [200, 409]
    with Session(db_engine) as session:
        assert session.get(HelpRequest, rid).status == "completed"
        with pytest.raises(HTTPException) as error:
            write(session)
        assert error.value.status_code == 409


@pytest.mark.parametrize("kind", ["offer", "message"])
def test_concurrent_retries_persist_one_row(db_engine, committed_graph, kind):
    ids, rid = committed_graph
    if kind == "message":
        offers = setup_offers(db_engine, ids, rid)
        with Session(db_engine) as session:
            accept_offer(session, offers[0].id, ids[0])

    def action(session):
        if kind == "offer":
            return create_offer(
                session, ids[1], OfferCreate(request_id=rid, message="Help"), "same-operation-key"
            )
        return create_message(
            session,
            ids[0],
            MessageCreate(request_id=rid, receiver_id=ids[1], body="Hi"),
            "same-operation-key",
        )

    assert run_race(db_engine, action, action) == [200, 200]
    model = Offer if kind == "offer" else Message
    with Session(db_engine) as session:
        count = session.scalar(
            select(func.count()).select_from(model).where(model.request_id == rid)
        )
        assert count == 1


@pytest.mark.parametrize(
    "model,changes",
    [
        (Offer, {"message": None}),
        (Offer, {"message": " "}),
        (Offer, {"helper_id": uuid4()}),
        (Offer, {"request_id": uuid4()}),
        (Offer, {"status": "invalid"}),
        (Offer, {"creation_hash": "bad"}),
        (Message, {"body": None}),
        (Message, {"body": " "}),
        (Message, {"sender_id": uuid4()}),
        (Message, {"receiver_id": uuid4()}),
        (Message, {"request_id": uuid4()}),
        (Message, {"creation_hash": "bad"}),
    ],
)
def test_database_rejects_invalid_records(db_engine, committed_graph, model, changes):
    ids, rid = committed_graph
    data = dict(request_id=rid, idempotency_key=str(uuid4()), creation_hash="a" * 64)
    if model is Offer:
        data.update(helper_id=ids[1], message="Help")
    else:
        data.update(sender_id=ids[0], receiver_id=ids[1], body="Hello")
    with Session(db_engine) as session:
        session.add(model(**(data | changes)))
        with pytest.raises(IntegrityError):
            session.flush()


def test_partial_unique_indexes_and_message_participants(db_engine, committed_graph):
    ids, rid = committed_graph
    offers = setup_offers(db_engine, ids, rid)
    with Session(db_engine) as session:
        session.add(
            Offer(
                request_id=rid,
                helper_id=ids[1],
                message="Duplicate",
                idempotency_key=str(uuid4()),
                creation_hash="a" * 64,
            )
        )
        with pytest.raises(IntegrityError):
            session.flush()
    with Session(db_engine) as session:
        for offer in offers:
            session.get(Offer, offer.id).status = "accepted"
        with pytest.raises(IntegrityError):
            session.flush()
    with Session(db_engine) as session:
        session.add(
            Message(
                request_id=rid,
                sender_id=ids[0],
                receiver_id=ids[0],
                body="Self",
                idempotency_key=str(uuid4()),
                creation_hash="a" * 64,
            )
        )
        with pytest.raises(IntegrityError):
            session.flush()


@pytest.mark.parametrize("kind", ["offer", "message"])
def test_creation_order_follows_insert_not_transaction_start(db_engine, committed_graph, kind):
    ids, rid = committed_graph
    if kind == "message":
        offers = setup_offers(db_engine, ids, rid)
        with Session(db_engine) as session:
            accept_offer(session, offers[0].id, ids[0])
    with Session(db_engine) as delayed:
        # Begin before another writer, but send only after that writer commits.
        delayed.execute(text("SELECT 1"))
        with Session(db_engine) as immediate:
            if kind == "message":
                data = MessageCreate(request_id=rid, receiver_id=ids[1], body="First")
                first, _ = create_message(immediate, ids[0], data, str(uuid4()))
            else:
                data = OfferCreate(request_id=rid, message="First")
                first, _ = create_offer(immediate, ids[2], data, str(uuid4()))
        if kind == "message":
            data = MessageCreate(request_id=rid, receiver_id=ids[1], body="Second")
            second, _ = create_message(delayed, ids[0], data, str(uuid4()))
        else:
            data = OfferCreate(request_id=rid, message="Second")
            second, _ = create_offer(delayed, ids[3], data, str(uuid4()))
    assert second.created_at > first.created_at


def test_migrations_preserve_prior_baselines(db_engine):
    with db_engine.begin() as connection:
        command.downgrade(migration_config(connection), "0410fbf8ced8")
        assert not inspect(connection).has_table("messages", schema="app_private")
        assert inspect(connection).has_table("offers", schema="app_private")
        command.downgrade(migration_config(connection), "cbcaea6d1d8d")
        assert not inspect(connection).has_table("offers", schema="app_private")
        assert inspect(connection).has_table("help_requests", schema="app_private")
        command.upgrade(migration_config(connection), "head")
        command.check(migration_config(connection))
        for table in ["offers", "messages"]:
            assert (
                connection.scalar(text("SELECT to_regclass(:name)"), {"name": f"public.{table}"})
                is None
            )
            count = connection.scalar(
                text("""
                SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace,
                LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
                WHERE n.nspname='app_private' AND c.relname=:table
                AND (a.grantee=0 OR a.grantee IN
                     (SELECT oid FROM pg_roles WHERE rolname IN ('anon', 'authenticated')))
            """),
                {"table": table},
            )
            assert count == 0
