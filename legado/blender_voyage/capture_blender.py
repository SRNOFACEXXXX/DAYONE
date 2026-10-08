"""Capture the visible Blender window on Windows using Pillow and Win32 GDI.

Read-only capture: does not click, type, change settings, or modify the scene.
Blender must be visible and unobstructed for an accurate screen capture.
"""
import ctypes
from ctypes import wintypes
from pathlib import Path
from PIL import ImageGrab

user32 = ctypes.WinDLL('user32', use_last_error=True)
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except (AttributeError, OSError):
    user32.SetProcessDPIAware()

windows = []
callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsIconic.argtypes = [wintypes.HWND]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]

@callback_type
def collect(hwnd, _):
    if user32.IsWindowVisible(hwnd) and not user32.IsIconic(hwnd):
        title = ctypes.create_unicode_buffer(user32.GetWindowTextLengthW(hwnd) + 1)
        user32.GetWindowTextW(hwnd, title, len(title))
        if 'voyage_rebuild_v3' in title.value and 'Blender' in title.value:
            windows.append((hwnd, title.value))
    return True

user32.EnumWindows(collect, 0)
if len(windows) != 1:
    raise SystemExit(f'Expected one visible Blender window, found: {[t for _, t in windows]}')
hwnd, title = windows[0]
rect = wintypes.RECT()
if not user32.GetClientRect(hwnd, ctypes.byref(rect)):
    raise ctypes.WinError(ctypes.get_last_error())
origin = wintypes.POINT(0, 0)
if not user32.ClientToScreen(hwnd, ctypes.byref(origin)):
    raise ctypes.WinError(ctypes.get_last_error())
bbox = (origin.x, origin.y, origin.x + rect.right, origin.y + rect.bottom)
output = Path(__file__).resolve().parent / 'blender_screen.png'
ImageGrab.grab(bbox=bbox, all_screens=True).save(output)
print(f'{title}\n{output}\nBounds: {bbox}')
