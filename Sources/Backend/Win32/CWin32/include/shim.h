#pragma once

// Include Direct2D shim
#include "d2d1_shim.h"

// Win32 shim layer for Swift.
// Swift's C importer cannot handle Win32 macros. This header provides
// inline C functions that expand those macros so Swift can call them.

#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include <windows.h>
#include <commctrl.h>
#include <windowsx.h>

// --- Macro expansions: word extraction ---

static inline WORD win32_LOWORD(DWORD_PTR value) {
    return LOWORD(value);
}

static inline WORD win32_HIWORD(DWORD_PTR value) {
    return HIWORD(value);
}

// --- Macro expansions: mouse coordinates from LPARAM ---

static inline int win32_GET_X_LPARAM(LPARAM lParam) {
    return GET_X_LPARAM(lParam);
}

static inline int win32_GET_Y_LPARAM(LPARAM lParam) {
    return GET_Y_LPARAM(lParam);
}

// --- Macro expansions: resource helpers ---

static inline LPCWSTR win32_MAKEINTRESOURCEW(WORD id) {
    return MAKEINTRESOURCEW(id);
}

// --- Macro expansions: color ---

static inline COLORREF win32_RGB(BYTE r, BYTE g, BYTE b) {
    return RGB(r, g, b);
}

static inline BYTE win32_GetRValue(COLORREF color) {
    return GetRValue(color);
}

static inline BYTE win32_GetGValue(COLORREF color) {
    return GetGValue(color);
}

static inline BYTE win32_GetBValue(COLORREF color) {
    return GetBValue(color);
}

// --- Window class names as functions (Swift can't use L"" string literals) ---

static inline LPCWSTR win32_WC_BUTTON(void) {
    return WC_BUTTONW;
}

static inline LPCWSTR win32_WC_STATIC(void) {
    return WC_STATICW;
}

static inline LPCWSTR win32_WC_EDIT(void) {
    return WC_EDITW;
}

static inline LPCWSTR win32_WC_COMBOBOX(void) {
    return WC_COMBOBOXW;
}

// --- Standard cursor IDs ---

static inline LPCWSTR win32_IDC_ARROW(void) {
    return MAKEINTRESOURCEW(32512);
}

static inline LPCWSTR win32_IDC_SIZEWE(void) {
    return MAKEINTRESOURCEW(32644);
}

// --- Subclassing helpers ---

static inline BOOL win32_SetWindowSubclass(
    HWND hwnd, SUBCLASSPROC pfnSubclass, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
    return SetWindowSubclass(hwnd, pfnSubclass, uIdSubclass, dwRefData);
}

static inline BOOL win32_RemoveWindowSubclass(
    HWND hwnd, SUBCLASSPROC pfnSubclass, UINT_PTR uIdSubclass) {
    return RemoveWindowSubclass(hwnd, pfnSubclass, uIdSubclass);
}

static inline LRESULT win32_DefSubclassProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

// --- Window property helpers ---

static inline LONG_PTR win32_GetWindowLongPtrW(HWND hwnd, int nIndex) {
    return GetWindowLongPtrW(hwnd, nIndex);
}

static inline LONG_PTR win32_SetWindowLongPtrW(HWND hwnd, int nIndex, LONG_PTR dwNewLong) {
    return SetWindowLongPtrW(hwnd, nIndex, dwNewLong);
}

// --- Common Controls initialization ---

static inline BOOL win32_InitCommonControlsEx(DWORD dwICC) {
    INITCOMMONCONTROLSEX icc;
    icc.dwSize = sizeof(icc);
    icc.dwICC = dwICC;
    return InitCommonControlsEx(&icc);
}

// --- Visual styles activation (ComCtl32 v6) ---
// Runtime workaround to enable ComCtl32 v6 without an embedded manifest.
// Uses shell32.dll resource 124 (undocumented but widely used compatibility
// hack — the proper solution is an application manifest, which SwiftPM
// doesn't support easily). Required for EM_SETCUEBANNER (placeholder text).
// Returns TRUE on success, FALSE if activation context could not be created.
static inline BOOL win32_EnableVisualStyles(void) {
    ACTCTXW actCtx = {0};
    actCtx.cbSize = sizeof(actCtx);
    actCtx.dwFlags = ACTCTX_FLAG_RESOURCE_NAME_VALID
                   | ACTCTX_FLAG_SET_PROCESS_DEFAULT
                   | ACTCTX_FLAG_ASSEMBLY_DIRECTORY_VALID;

    WCHAR sysDir[MAX_PATH];
    GetSystemDirectoryW(sysDir, MAX_PATH);
    actCtx.lpAssemblyDirectory = sysDir;
    actCtx.lpSource = L"shell32.dll";
    actCtx.lpResourceName = MAKEINTRESOURCEW(124);

    HANDLE hActCtx = CreateActCtxW(&actCtx);
    if (hActCtx == INVALID_HANDLE_VALUE) return FALSE;

    // ACTCTX_FLAG_SET_PROCESS_DEFAULT makes this process-wide.
    // We intentionally do not deactivate — the activation lives for
    // the process lifetime (same as a manifest). The creation handle
    // is released; the activated context stays alive independently.
    ULONG_PTR cookie = 0;
    BOOL ok = ActivateActCtx(hActCtx, &cookie);
    ReleaseActCtx(hActCtx);
    return ok;
}

// --- DPI awareness ---

static inline BOOL win32_SetProcessDpiAwarenessContextPerMonitorV2(void) {
    return SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
}

static inline UINT win32_GetDpiForWindow(HWND hwnd) {
    return GetDpiForWindow(hwnd);
}

// --- Text measurement ---

static inline BOOL win32_GetTextExtentPoint32W(HDC hdc, LPCWSTR text, int len, SIZE *size) {
    return GetTextExtentPoint32W(hdc, text, len, size);
}

// --- Convenience: Create a window with standard parameters ---

static inline HWND win32_CreateChildWindow(
    LPCWSTR className, LPCWSTR text, DWORD style,
    int x, int y, int width, int height,
    HWND parent, HMENU id, HINSTANCE hInstance) {
    return CreateWindowExW(0, className, text,
        WS_CHILD | WS_VISIBLE | style,
        x, y, width, height,
        parent, id, hInstance, NULL);
}
