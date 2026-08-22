"""Request ID assignment and propagation."""

from collections.abc import Awaitable, Callable
from uuid import UUID, uuid4

from fastapi import FastAPI, Request, Response

REQUEST_ID_HEADER = "X-Request-ID"


def install_request_id_middleware(app: FastAPI) -> None:
    """Add a bounded UUID request identifier to every request and response."""

    @app.middleware("http")
    async def add_request_id(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        request.state.request_id = _request_id(request.headers.get(REQUEST_ID_HEADER))
        response = await call_next(request)
        response.headers[REQUEST_ID_HEADER] = str(request.state.request_id)
        return response


def _request_id(value: str | None) -> UUID:
    if value is not None:
        try:
            return UUID(value)
        except ValueError:
            pass
    return uuid4()
