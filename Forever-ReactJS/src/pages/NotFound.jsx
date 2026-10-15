import { Link } from 'react-router-dom';

const NotFound = () => (
  <div className="flex min-h-[60vh] flex-col items-center justify-center border-t text-center">
    <p className="text-sm uppercase tracking-[0.3em] text-gray-400">404 error</p>
    <h1 className="mt-3 text-4xl font-medium">Page not found</h1>
    <p className="mt-4 max-w-md text-gray-500">The page may have moved, or the address might be incorrect.</p>
    <Link to="/" className="mt-7 bg-black px-7 py-3 text-sm text-white">Return home</Link>
  </div>
);

export default NotFound;
