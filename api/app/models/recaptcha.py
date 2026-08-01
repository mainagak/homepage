from dataclasses import dataclass


@dataclass
class RecaptchaOutcome:
    status_code: int
    body: dict
