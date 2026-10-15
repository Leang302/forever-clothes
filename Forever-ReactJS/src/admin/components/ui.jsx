// Small presentational pieces shared by the admin pages.
import { useEffect, useRef, useState } from "react";
import { STATUSES } from "../format";

export const StatusBadge = ({ status }) => {
  const [, label, color] = STATUSES.find(([v]) => v === status) || [status, status, 'bg-gray-100 text-gray-600'];
  return <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium whitespace-nowrap ${color}`}>{label}</span>;
};

export const PageTitle = ({ title, children }) => (
  <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
    <h1 className="text-2xl font-medium">{title}</h1>
    <div className="flex items-center gap-3">{children}</div>
  </div>
);

export const Card = ({ className = '', children }) => (
  <div className={`bg-white border border-gray-200 rounded-lg ${className}`}>{children}</div>
);

export const Pagination = ({ page, totalPages, onChange }) => {
  if (totalPages <= 1) return null;
  return (
    <div className="flex items-center justify-between mt-4 text-sm">
      <span className="text-gray-500">Page {page + 1} of {totalPages}</span>
      <div className="flex gap-2">
        <button disabled={page === 0} onClick={() => onChange(page - 1)} className="border px-3 py-1.5 rounded bg-white disabled:opacity-40">Previous</button>
        <button disabled={page + 1 >= totalPages} onClick={() => onChange(page + 1)} className="border px-3 py-1.5 rounded bg-white disabled:opacity-40">Next</button>
      </div>
    </div>
  );
};

export const Loading = () => <p className="py-10 text-center text-gray-400">Loading...</p>;

export const ErrorText = ({ error }) => error ? <p className="py-6 text-center text-red-600">{error.message}</p> : null;

export const Empty = ({ children }) => <p className="py-12 text-center text-gray-400">{children}</p>;

export const Stat = ({ label, value, hint, tone = '' }) => (
  <Card className="p-5">
    <p className="text-sm text-gray-500">{label}</p>
    <p className={`text-3xl font-medium mt-2 ${tone}`}>{value}</p>
    {hint && <p className="text-xs text-gray-400 mt-1">{hint}</p>}
  </Card>
);

// Two-step delete: the first click asks, the second click runs `onConfirm`.
export const ConfirmDelete = ({ onConfirm, label = 'Delete', busy = false }) => {
  const [asking, setAsking] = useState(false);
  if (!asking) {
    return (
      <button type="button" onClick={() => setAsking(true)} className="text-sm text-red-600 hover:underline">
        {label}
      </button>
    );
  }
  return (
    <span className="inline-flex items-center gap-2 text-sm">
      <span className="text-gray-500">Sure?</span>
      <button
        type="button"
        disabled={busy}
        onClick={async () => {
          await onConfirm();
          setAsking(false);
        }}
        className="bg-red-600 text-white rounded px-2.5 py-1 disabled:opacity-50"
      >
        Yes, delete
      </button>
      <button type="button" onClick={() => setAsking(false)} className="text-gray-500 hover:underline">
        Cancel
      </button>
    </span>
  );
};

export const SearchInput = ({ value, onChange, placeholder = 'Search', className = 'w-full sm:w-72' }) => (
  <div className={`relative ${className}`}>
    <input
      type="search"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="border border-gray-300 rounded pl-3 pr-8 py-2 text-sm bg-white w-full"
    />
    {value && (
      <button
        type="button"
        onClick={() => onChange('')}
        aria-label="Clear search"
        className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-black"
      >
        ×
      </button>
    )}
  </div>
);

// Clickable table header. `sort` is { key, dir } and `onSort(key)` toggles it.
export const SortTh = ({ label, sortKey, sort, onSort, className = '' }) => {
  const active = sort.key === sortKey;
  const arrow = active ? (sort.dir === 'asc' ? '▲' : '▼') : '↕';
  return (
    <th className={`px-4 py-3 font-normal ${className}`} aria-sort={active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}>
      <button
        type="button"
        onClick={() => onSort(sortKey)}
        className={`inline-flex items-center gap-1 hover:text-black ${active ? 'text-black font-medium' : ''}`}
      >
        {label}
        <span className={`text-[10px] ${active ? '' : 'text-gray-300'}`}>{arrow}</span>
      </button>
    </th>
  );
};

// Checkbox dropdown for picking several values (e.g. categories).
export const MultiSelect = ({ label, options, value, onChange }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const close = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [open]);

  const toggle = (option) =>
    onChange(value.includes(option) ? value.filter((v) => v !== option) : [...value, option]);

  const summary = value.length === 0 ? `All ${label.toLowerCase()}` : value.length <= 2 ? value.join(', ') : `${value.length} ${label.toLowerCase()}`;

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className={`border rounded px-3 py-2 text-sm bg-white flex items-center gap-2 ${value.length ? 'border-black' : 'border-gray-300'}`}
      >
        <span className="max-w-[12rem] truncate">{summary}</span>
        <span className="text-xs text-gray-400">▾</span>
      </button>
      {open && (
        <div className="absolute z-20 mt-1 w-56 bg-white border border-gray-200 rounded-lg shadow-lg p-2">
          {options.length === 0 && <p className="px-2 py-1 text-sm text-gray-400">Nothing to choose</p>}
          <div className="max-h-64 overflow-auto">
            {options.map((option) => (
              <label key={option} className="flex items-center gap-2 px-2 py-1.5 rounded text-sm hover:bg-gray-50 cursor-pointer">
                <input type="checkbox" checked={value.includes(option)} onChange={() => toggle(option)} className="accent-black" />
                {option}
              </label>
            ))}
          </div>
          {value.length > 0 && (
            <button type="button" onClick={() => onChange([])} className="w-full mt-1 border-t pt-2 text-xs text-gray-500 hover:text-black">
              Clear selection
            </button>
          )}
        </div>
      )}
    </div>
  );
};

// Segmented control, e.g. All / Visible / Hidden.
export const Segmented = ({ options, value, onChange }) => (
  <div className="inline-flex rounded border border-gray-300 bg-white overflow-hidden text-sm">
    {options.map(([v, label]) => (
      <button
        key={String(v)}
        type="button"
        onClick={() => onChange(v)}
        className={`px-3 py-2 ${value === v ? 'bg-black text-white' : 'text-gray-600 hover:bg-gray-100'}`}
      >
        {label}
      </button>
    ))}
  </div>
);
