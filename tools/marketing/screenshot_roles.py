"""Explicit native screenshot roles; caption reuse never permits image substitution."""
from dataclasses import dataclass
from types import MappingProxyType


@dataclass(frozen=True)
class ScreenshotRole:
    caption_device: str
    native_size: tuple[int, int]
    frame_count: int
    simulator_names: tuple[str, ...] = ()


ROLES = MappingProxyType({
    'iphone': ScreenshotRole('iphone', (1206, 2622), 9,
                             ('iPhone 17 Pro', 'iPhone 16 Pro')),
    'iphone-large': ScreenshotRole('iphone', (1320, 2868), 9,
                                   ('iPhone 17 Pro Max', 'iPhone 16 Pro Max')),
    # The runner retains its existing native 13-inch iPad selector.
    'ipad': ScreenshotRole('ipad', (2752, 2064), 4),
})
SCREENSHOT_KINDS = tuple(ROLES)


def screenshot_role(kind: str) -> ScreenshotRole:
    """Reject unknown roles instead of silently selecting a phone or tablet."""
    try:
        return ROLES[kind]
    except (KeyError, TypeError) as error:
        raise ValueError(f'Unknown screenshot role: {kind!r}') from error


def expected_screenshot_count(locales: list[str], kinds=SCREENSHOT_KINDS) -> int:
    """Count only distinct, explicit screenshot roles, excluding contact sheets/videos."""
    if len(locales) != len(set(locales)) or len(kinds) != len(set(kinds)):
        raise ValueError('Screenshot coverage cannot count duplicate locales or roles')
    return len(locales) * sum(screenshot_role(kind).frame_count for kind in kinds)
