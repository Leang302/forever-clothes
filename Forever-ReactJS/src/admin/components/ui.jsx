// Small presentational pieces shared by the admin pages.
import { useEffect, useRef, useState } from "react";
import { XIcon } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
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

// Page numbers to show: always the first and last, plus the pages around the current one; null = "…".
const pageNumbers = (page, totalPages) => {
  const wanted = new Set([0, totalPages - 1, page - 1, page, page + 1].filter((p) => p >= 0 && p < totalPages));
  const sorted = [...wanted].sort((a, b) => a - b);
  return sorted.flatMap((p, i) => (i > 0 && p - sorted[i - 1] > 1 ? [null, p] : [p]));
};

/**
 * Always visible below a list (even with a single page) so it is clear how many items there are.
 * `total` and `pageSize` are optional; with them it shows "Showing 11–20 of 42".
 */
export const Pagination = ({ page, totalPages, onChange, total, pageSize }) => {
  if (total === 0) return null; // the empty state already says there is nothing
  const pages = Math.max(totalPages || 1, 1);
  const current = Math.min(page, pages - 1);
  const summary = total != null && pageSize
    ? `Showing ${current * pageSize + 1}–${Math.min((current + 1) * pageSize, total)} of ${total}`
    : `Page ${current + 1} of ${pages}`;
  const btn = 'min-w-9 h-9 px-3 rounded border text-sm disabled:opacity-40 disabled:cursor-not-allowed';
  return (
    <nav aria-label="Pagination" className="flex flex-wrap items-center justify-between gap-3 mt-4 text-sm">
      <span className="text-gray-500">{summary}</span>
      <div className="flex items-center gap-1">
        <button type="button" disabled={current === 0} onClick={() => onChange(current - 1)} className={`${btn} bg-white hover:bg-gray-100`}>
          Previous
        </button>
        {pageNumbers(current, pages).map((p, i) =>
          p === null ? (
            <span key={`gap-${i}`} className="px-1 text-gray-400">…</span>
          ) : (
            <button
              type="button"
              key={p}
              onClick={() => onChange(p)}
              aria-current={p === current ? 'page' : undefined}
              className={`${btn} ${p === current ? 'bg-black text-white border-black' : 'bg-white hover:bg-gray-100'}`}
            >
              {p + 1}
            </button>
          ),
        )}
        <button type="button" disabled={current + 1 >= pages} onClick={() => onChange(current + 1)} className={`${btn} bg-white hover:bg-gray-100`}>
          Next
        </button>
      </div>
    </nav>
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
      type="text" // not "search": browsers add their own clear button next to ours
      role="searchbox"
      onKeyDown={(e) => e.key === 'Escape' && onChange('')}
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

// "× Clear filters" for list pages; `count` (optional) is how many filters are active.
export const ClearFilters = ({ onClick, count }) => (
  <button
    type="button"
    onClick={onClick}
    className="inline-flex items-center gap-1.5 rounded-full border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-600 hover:border-black hover:text-black"
  >
    <XIcon className="size-3.5" />
    Clear filters{count > 0 ? ` (${count})` : ''}
  </button>
);

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
        className={`border rounded py-2 pl-3 text-sm bg-white flex items-center gap-2 ${value.length ? 'border-black pr-8' : 'border-gray-300 pr-3'}`}
      >
        <span className="max-w-[12rem] truncate">{summary}</span>
        {!value.length && <span className="text-xs text-gray-400">▾</span>}
      </button>
      {value.length > 0 && (
        <button
          type="button"
          onClick={() => onChange([])}
          aria-label={`Clear ${label.toLowerCase()} filter`}
          title="Clear"
          className="absolute right-1.5 top-1/2 -translate-y-1/2 rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-black"
        >
          <XIcon className="size-3.5" />
        </button>
      )}
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

// Radix Select reserves "" for "nothing selected", so "" options (e.g. "All statuses") go through a stand-in value.
const EMPTY = '__empty__';

/**
 * shadcn/ui dropdown. `options` is a list of [value, label] pairs; `onChange` receives the value.
 * `""` is allowed as an option value, which the filters use for "All".
 */
export const Dropdown = ({ value, onChange, options, placeholder = 'Select', className = '', contentClassName = '', disabled, ...props }) => (
  // "" is the "All"-style option when the list has one; otherwise it means nothing chosen, and Radix shows the
  // placeholder for "".
  <Select
    value={value === '' || value == null ? (options.some(([v]) => v === '') ? EMPTY : '') : String(value)}
    onValueChange={(v) => onChange(v === EMPTY ? '' : v)}
    disabled={disabled}
  >
    <SelectTrigger className={`bg-white border-gray-300 rounded ${className}`} {...props}>
      <SelectValue placeholder={placeholder} />
    </SelectTrigger>
    {/* Inside a modal, pass a z-index above the modal's, e.g. contentClassName="z-[1200]". */}
    <SelectContent className={contentClassName}>
      {options.map(([v, label]) => (
        <SelectItem key={v === '' ? EMPTY : v} value={v === '' ? EMPTY : String(v)}>
          {label}
        </SelectItem>
      ))}
    </SelectContent>
  </Select>
);

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
