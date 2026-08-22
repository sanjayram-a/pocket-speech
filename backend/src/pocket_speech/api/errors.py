"""Safe public API error handling."""

import logging
from uuid import UUID

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.status import HTTP_404_NOT_FOUND, HTTP_405_METHOD_NOT_ALLOWED

logger = logging.getLogger(__name__)


class ErrorResponse(BaseModel):
    """Stable error body safe to return to clients."""

    model_config = ConfigDict(extra="forbid")

    code: str
    message: str
    retryable: bool
    request_id: UUID


class ApiError(Exception):
    """An expected error with a safe public representation."""

    def __init__(
        self,
        *,
        status_code: int,
        code: str,
        message: str,
        retryable: bool = False,
        headers: dict[str, str] | None = None,
    ) -> None:
        """Capture only fields explicitly safe for API clients."""
        super().__init__(code)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.retryable = retryable
        self.headers = headers


def install_error_handlers(app: FastAPI) -> None:
    """Install handlers that never expose exception details or request bodies."""
    app.add_exception_handler(ApiError, _api_error_handler)
    app.add_exception_handler(RequestValidationError, _validation_error_handler)
    app.add_exception_handler(StarletteHTTPException, _http_error_handler)
    app.add_exception_handler(Exception, _unexpected_error_handler)


async def _api_error_handler(request: Request, error: Exception) -> JSONResponse:
    api_error = _narrow_exception(error, ApiError)
    return _error_response(request, api_error)


async def _validation_error_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    _narrow_exception(error, RequestValidationError)
    return _error_response(
        request,
        ApiError(
            status_code=422,
            code="invalid_request",
            message="Request validation failed.",
            retryable=False,
        ),
    )


async def _http_error_handler(request: Request, error: Exception) -> JSONResponse:
    http_error = _narrow_exception(error, StarletteHTTPException)
    if http_error.status_code == HTTP_404_NOT_FOUND:
        code, message = "not_found", "Resource not found."
    elif http_error.status_code == HTTP_405_METHOD_NOT_ALLOWED:
        code, message = "method_not_allowed", "Method not allowed."
    else:
        code, message = "request_failed", "Request could not be completed."
    return _error_response(
        request,
        ApiError(
            status_code=http_error.status_code,
            code=code,
            message=message,
            headers=http_error.headers,
        ),
    )


async def _unexpected_error_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    logger.error(
        "Unhandled request failure request_id=%s error_type=%s",
        request.state.request_id,
        type(error).__name__,
    )
    return _error_response(
        request,
        ApiError(
            status_code=500,
            code="temporary_service_failure",
            message="The service could not complete the request.",
            retryable=True,
        ),
    )


def _error_response(
    request: Request,
    error: ApiError,
) -> JSONResponse:
    body = ErrorResponse(
        code=error.code,
        message=error.message,
        retryable=error.retryable,
        request_id=request.state.request_id,
    )
    return JSONResponse(
        status_code=error.status_code,
        content=body.model_dump(mode="json"),
        headers=error.headers,
    )


def _narrow_exception[ExceptionType: Exception](
    error: Exception,
    expected: type[ExceptionType],
) -> ExceptionType:
    if isinstance(error, expected):
        return error
    raise AssertionError from error
