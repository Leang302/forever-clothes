// Data fetched on the server for the current route (Home / Collection / Product), passed down so the
// first render (both the HTML the server sends and the client's hydration pass) has real content instead
// of an empty shell. Null on any route that isn't server-rendered, or when SSR fetching failed.
//
// In the browser the data is only handed out during the hydration render: once the first commit is done
// (SSRDataProvider's effect, which runs after every child's), useSSRData() returns null, so a page that
// mounts later (client-side navigation back to "/", another /collection filter, ...) fetches fresh data
// instead of reusing the stale snapshot from the initial page load.
import { createContext, useContext, useEffect } from 'react';

export const SSRDataContext = createContext(null);

// The absolute public origin of the site (e.g. https://shop.example.com), used for share links and
// canonical URLs. Set per request on the server (PUBLIC_SITE_URL or the request host) and passed to the
// browser as window.__SITE_URL__, so server and client render the same absolute links.
export const SiteUrlContext = createContext('');

const isServer = typeof window === 'undefined';
let hydrating = !isServer;

export const useSSRData = () => {
  const value = useContext(SSRDataContext);
  return isServer || hydrating ? value : null;
};

export const useSiteUrl = () => useContext(SiteUrlContext);

export const SSRDataProvider = ({ value, siteUrl, children }) => {
  useEffect(() => {
    hydrating = false;
  }, []);
  return (
    <SiteUrlContext.Provider value={siteUrl}>
      <SSRDataContext.Provider value={value}>{children}</SSRDataContext.Provider>
    </SiteUrlContext.Provider>
  );
};

export default SSRDataContext;
