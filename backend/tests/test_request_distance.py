import pytest
from pydantic import ValidationError

from app.schemas.requests import RequestCreate, RequestUpdate


def valid_payload():
    return dict(
        title=" Groceries ",
        description=" Need food ",
        category="FOOD_ASSISTANCE",
        urgency="standard",
        latitude=35.4676,
        longitude=-97.5164,
        area=" Midtown ",
    )


def test_create_normalizes_text():
    value = RequestCreate(**valid_payload())
    assert value.title == "Groceries"
    assert value.description == "Need food"
    assert value.area == "Midtown"


@pytest.mark.parametrize(
    "change",
    [
        {"title": " "},
        {"title": "x" * 121},
        {"description": "x" * 4001},
        {"area": "x" * 101},
        {"title": "bad\x00"},
        {"title": "\ud800"},
        {"latitude": float("nan")},
        {"longitude": float("inf")},
        {"latitude": 91},
        {"longitude": -181},
        {"title": 1},
        {"status": "active"},
        {"requester_id": "x"},
        {"category": "food"},
        {"urgency": "urgent"},
    ],
)
def test_create_rejects_invalid_or_protected_fields(change):
    with pytest.raises(ValidationError):
        RequestCreate(**(valid_payload() | change))


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"latitude": 0},
        {"longitude": 0},
        {"title": None},
        {"area": None},
        {"status": None},
        {"unknown": "x"},
    ],
)
def test_update_rejects_empty_null_and_unpaired_coordinates(payload):
    with pytest.raises(ValidationError):
        RequestUpdate(**payload)


def test_update_can_change_coordinate_pair_and_close():
    update = RequestUpdate(latitude=0, longitude=0, status="completed")
    assert update.model_dump(exclude_unset=True) == {
        "latitude": 0,
        "longitude": 0,
        "status": "completed",
    }
