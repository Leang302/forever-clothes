import { useEffect, useRef, useState } from "react";

// Runs an async loader when `deps` change and exposes { data, loading, error }.
// `initial`, when given (e.g. data fetched during SSR for this exact first render), seeds the state so the
// first client render matches the server-rendered HTML and skips the otherwise-immediate refetch, so
// hydration doesn't flash "Loading..." over content that's already on screen.
export default function useApi(loader, deps, initial = null) {
  const [state, setState] = useState(() =>
    initial !== null ? { data: initial, loading: false, error: null } : { data: null, loading: true, error: null },
  );
  const skipNext = useRef(initial !== null);

  useEffect(() => {
    if (skipNext.current) {
      skipNext.current = false;
      return undefined;
    }
    let cancelled = false;
    setState((s) => ({ ...s, loading: true, error: null }));
    loader()
      .then((data) => !cancelled && setState({ data, loading: false, error: null }))
      .catch((error) => !cancelled && setState({ data: null, loading: false, error }));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
