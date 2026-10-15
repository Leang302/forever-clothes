import { useCallback, useEffect, useRef } from "react";
import { useBlocker } from "react-router-dom";
import ConfirmDialog from "./ConfirmDialog";

/**
 * Asks before leaving a form with unsaved changes: in-app links, the browser back button, refresh and
 * closing the tab. Returns the dialog to render and `allowLeave()`, which a successful save calls right
 * before navigating away so its own redirect is not blocked.
 */
export default function useUnsavedChanges(dirty, message = 'You have unsaved changes. Leave this page and discard them?') {
  const dirtyRef = useRef(dirty);
  const allowedRef = useRef(false);
  dirtyRef.current = dirty;

  const blocker = useBlocker(useCallback(
    ({ currentLocation, nextLocation }) =>
      dirtyRef.current && !allowedRef.current && currentLocation.pathname !== nextLocation.pathname,
    [],
  ));

  // Refresh / close tab / typing a new URL: only the browser's own prompt is allowed here.
  useEffect(() => {
    if (!dirty) return undefined;
    const onBeforeUnload = (e) => { e.preventDefault(); e.returnValue = ''; };
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  }, [dirty]);

  const allowLeave = useCallback(() => { allowedRef.current = true; }, []);

  const dialog = blocker.state === 'blocked' ? (
    <ConfirmDialog message={message} onCancel={() => blocker.reset()} onConfirm={() => blocker.proceed()} />
  ) : null;

  return { dialog, allowLeave };
}
