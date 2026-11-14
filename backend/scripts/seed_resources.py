"""Validate and optionally insert the curated Sprint 4 resource dataset."""

import argparse
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated
from uuid import NAMESPACE_URL, uuid5

from pydantic import (
    AnyHttpUrl,
    AwareDatetime,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    TypeAdapter,
    field_validator,
)
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database.session import get_engine
from app.models import Resource
from app.schemas.requests import Area, Latitude, Longitude, normalize_text
from app.schemas.resources import ResourceCategory

SEED_PATH = Path(__file__).resolve().parents[1] / "data" / "okc_metro_resources.json"


class SeedResource(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    name: Annotated[str, BeforeValidator(normalize_text), Field(min_length=1, max_length=160)]
    category: ResourceCategory
    area: Area
    address: Annotated[str, BeforeValidator(normalize_text), Field(min_length=1, max_length=300)]
    latitude: Latitude
    longitude: Longitude
    phone: (
        Annotated[str, BeforeValidator(normalize_text), Field(min_length=1, max_length=40)] | None
    )
    website: AnyHttpUrl | None
    source_url: AnyHttpUrl
    last_verified_at: AwareDatetime

    @field_validator("website", "source_url")
    @classmethod
    def validate_provider_url(cls, value: AnyHttpUrl | None) -> AnyHttpUrl | None:
        if value is not None and (value.username or value.password or len(str(value)) > 2048):
            raise ValueError("Use a public provider URL of at most 2048 characters.")
        return value

    @field_validator("last_verified_at")
    @classmethod
    def validate_verification_date(cls, value: datetime) -> datetime:
        if value > datetime.now(UTC):
            raise ValueError("Verification date cannot be in the future.")
        return value


def load_seed(path: Path = SEED_PATH) -> list[SeedResource]:
    records = TypeAdapter(Annotated[list[SeedResource], Field(min_length=1)]).validate_json(
        path.read_text(encoding="utf-8")
    )
    if len({str(record.source_url) for record in records}) != len(records):
        raise ValueError("Duplicate source URL in resource dataset.")
    return records


def seed_resources(session: Session, records: list[SeedResource]) -> int:
    values = [
        record.model_dump(exclude={"website", "source_url"})
        | {
            "id": uuid5(NAMESPACE_URL, str(record.source_url)),
            "website": str(record.website) if record.website is not None else None,
            "source_url": str(record.source_url),
        }
        for record in records
    ]
    inserted = session.scalars(
        insert(Resource)
        .values(values)
        .on_conflict_do_nothing(index_elements=[Resource.id])
        .returning(Resource.id)
    ).all()
    return len(inserted)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Insert into the configured database.")
    args = parser.parse_args()
    try:
        records = load_seed()
        if not args.apply:
            print(f"Validated {len(records)} curated listings.")
            return
        with Session(get_engine()) as session, session.begin():
            count = seed_resources(session, records)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Resource seed failed: {error}\n")
    except SQLAlchemyError:
        parser.exit(1, "Resource seed failed. Check database access and apply the migration.\n")
    print(f"Inserted {count} listings. {len(records) - count} already existed.")


if __name__ == "__main__":
    main()
