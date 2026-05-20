"""
drink-dispenser — Dispense drinks on GPIO pins based on game events.

Reads JSON events from stdin (piped from another process).

Expected JSON format (one object per line):
    {"event": "hit_banana", "playerIndex": 2}

Behaviour:
- Events in ALLOWLIST for a known playerIndex activate the player's GPIO pin.
- The pin stays ACTIVE for 1.5 s after the *last* event for that pin.
- Events arriving while the pin is already ACTIVE extend the deadline rather
    than toggling the pin off and on again.
- Non-JSON lines and events not in ALLOWLIST are silently ignored (logged).

"""

import json
import logging
import sys
import threading
import time

import gpiod
import gpiod.line

logging.basicConfig(level=logging.INFO)


PLAYER_TO_GPIO: dict[int, int] = {
    0: 5,
    1: 6,
    2: 13,
    3: 16,
    4: 19,
    5: 20,
    6: 21,
    7: 26,
}

EVENT_DURATIONS: dict[str, float] = {
    "driving_spinout": 1.5,
    "early_start_spinout": 1.5,
    "explosion_crash": 1.5,
    "fell_in_lava": 1.5,
    "fell_in_water": 1.5,
    "high_tumble": 1.5,
    "hit_banana": 1.5,
    "hit_by_star": 1.5,
    "hit_paddle_boat": 1.5,
    "lightning_strike": 1.5,
    "low_tumble": 1.5,
    "negroni_code": 0.1,
    "spinout": 1.5,
    "squished": 1.5,
    "terrain_tumble": 1.5,
    # FIXME: if player hits CPU
    # issue # {"event":"star_hit", "ownerIndex":2, "playerIndex":0,
    # "isHumanOwner":false, "isHumanPlayer":true}
}
GPIO_CHIP: str = "/dev/gpiochip0"
CONSUMER: str = "drink-dispenser"


def init_gpio() -> gpiod.LineRequest:
    config = {
        pin: gpiod.LineSettings(
            active_low=True,
            direction=gpiod.line.Direction.OUTPUT,
            output_value=gpiod.line.Value.INACTIVE,
        )
        for pin in PLAYER_TO_GPIO.values()
    }
    request = gpiod.request_lines(GPIO_CHIP, config=config, consumer=CONSUMER)
    logging.info("GPIO initialized — all pins set to INACTIVE")
    return request


class PinController:
    """Keeps a GPIO pin ACTIVE until ON_DURATION seconds after the last event."""

    def __init__(self, pin: int, request: gpiod.LineRequest) -> None:
        self._pin = pin
        self._request = request
        self._lock = threading.Lock()
        self._deadline: float | None = None
        self._active = False
        self._timer: threading.Timer | None = None

    def trigger(self, duration: float) -> None:
        """Extend (or start) the active window by duration from now."""
        new_deadline = float(time.monotonic() + duration)
        with self._lock:
            self._deadline = new_deadline
            if not self._active:
                self._active = True
                self._request.set_value(self._pin, gpiod.line.Value.ACTIVE)
                logging.info(f"GPIO {self._pin} ON")
            self._reschedule_locked()

    def turn_off(self) -> None:
        """Unconditionally deactivate the pin (used during shutdown)."""
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
                self._timer = None
            self._deadline = None
            self._active = False
            self._request.set_value(self._pin, gpiod.line.Value.INACTIVE)

    def _reschedule_locked(self) -> None:
        if self._timer is not None:
            self._timer.cancel()
        delay = (
            max(0.0, self._deadline - time.monotonic())
            if self._deadline is not None
            else 0.0
        )
        self._timer = threading.Timer(delay, self._maybe_turn_off)
        self._timer.daemon = True
        self._timer.start()

    def _maybe_turn_off(self) -> None:
        with self._lock:
            if self._deadline is not None and time.monotonic() < self._deadline:
                # Timer fired slightly early; a fresh timer is already armed.
                return
            if self._active:
                self._active = False
                self._deadline = None
                self._request.set_value(self._pin, gpiod.line.Value.INACTIVE)
                logging.info(f"GPIO {self._pin} OFF")
            self._timer = None


def main() -> None:
    line_request = init_gpio()
    controllers = {
        player: PinController(pin, line_request)
        for player, pin in PLAYER_TO_GPIO.items()
    }

    try:
        for raw_line in sys.stdin:
            raw_line = raw_line.strip()
            if not raw_line:
                continue

            try:
                data = json.loads(raw_line)
            except json.JSONDecodeError:
                continue

            logging.info(f"Got event: {raw_line}")

            event = data.get("event")
            if event is None:
                continue
            if event not in EVENT_DURATIONS:
                logging.info(f"Event '{event}' not in event durations, skipping")
                continue

            player_index = data.get("playerIndex")
            if player_index is None:
                continue

            ctrl = controllers.get(player_index)
            if ctrl is None:
                continue

            gpio_pin = PLAYER_TO_GPIO[player_index]
            duration = EVENT_DURATIONS[event]
            logging.info(
                f"Dispensing drink for Player #{player_index} (event: {event}, gpio: {gpio_pin}, duration: {duration}s)"
            )
            ctrl.trigger(duration)

    except KeyboardInterrupt:
        pass
    finally:
        for ctrl in controllers.values():
            ctrl.turn_off()
        line_request.release()
        logging.info("GPIO released — all pins INACTIVE")


if __name__ == "__main__":
    main()
