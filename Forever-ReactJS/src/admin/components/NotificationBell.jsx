import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, CircleX, PackageX, ShoppingBag, UserPlus } from "lucide-react";
import { api } from "../../api/client";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";

const POLL_MS = 30_000;

const TYPE_ICON = {
  NEW_ORDER: [ShoppingBag, 'bg-green-100 text-green-700'],
  ORDER_CANCELLED: [CircleX, 'bg-red-100 text-red-700'],
  LOW_STOCK: [PackageX, 'bg-amber-100 text-amber-700'],
  NEW_CUSTOMER: [UserPlus, 'bg-blue-100 text-blue-700'],
};

const timeAgo = (iso) => {
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
};

// Admin notification bell: unread badge, refreshed every 30 s and when the tab regains focus.
const NotificationBell = () => {
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [data, setData] = useState({ items: [], unreadCount: 0 });
  const [error, setError] = useState(null);

  const load = useCallback(() => {
    api
      .adminNotifications({ unreadOnly, limit: 20 })
      .then((d) => {
        setData(d);
        setError(null);
      })
      .catch(setError);
  }, [unreadOnly]);

  useEffect(() => {
    load();
    const timer = setInterval(load, POLL_MS);
    const onFocus = () => load();
    window.addEventListener('focus', onFocus);
    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', onFocus);
    };
  }, [load]);

  const openItem = async (n) => {
    setOpen(false);
    if (!n.read) {
      setData((d) => ({
        items: d.items.map((x) => (x.id === n.id ? { ...x, read: true } : x)),
        unreadCount: Math.max(0, d.unreadCount - 1),
      }));
      api.adminReadNotification(n.id).catch(load);
    }
    if (n.link) navigate(n.link);
  };

  const readAll = async () => {
    setData((d) => ({ items: d.items.map((x) => ({ ...x, read: true })), unreadCount: 0 }));
    await api.adminReadAllNotifications().catch(() => {});
    load();
  };

  const count = data.unreadCount;

  return (
    <Popover open={open} onOpenChange={(o) => { setOpen(o); if (o) load(); }}>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label={count ? `Notifications, ${count} unread` : 'Notifications'}
          className="relative rounded p-1.5 text-gray-600 hover:bg-gray-100 hover:text-black"
        >
          <Bell className="size-5" />
          {count > 0 && (
            <span className="absolute -right-0.5 -top-0.5 min-w-[1.1rem] rounded-full bg-red-600 px-1 text-center text-[10px] font-semibold leading-[1.1rem] text-white">
              {count > 99 ? '99+' : count}
            </span>
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-[22rem] max-w-[calc(100vw-2rem)] p-0">
        <div className="flex items-center justify-between border-b px-4 py-3">
          <p className="font-medium">Notifications</p>
          <div className="flex items-center gap-3 text-xs">
            <button type="button" onClick={() => setUnreadOnly((u) => !u)} className="text-gray-500 hover:text-black">
              {unreadOnly ? 'Show all' : 'Unread only'}
            </button>
            {count > 0 && (
              <button type="button" onClick={readAll} className="text-gray-500 hover:text-black">
                Mark all read
              </button>
            )}
          </div>
        </div>
        {error && <p className="px-4 py-6 text-center text-sm text-red-600">{error.message}</p>}
        {!error && data.items.length === 0 && (
          <p className="px-4 py-10 text-center text-sm text-gray-400">{unreadOnly ? 'No unread notifications' : 'No notifications yet'}</p>
        )}
        <ul className="max-h-[60vh] divide-y overflow-auto">
          {data.items.map((n) => {
            const [Icon, tone] = TYPE_ICON[n.type] || [Bell, 'bg-gray-100 text-gray-600'];
            return (
              <li key={n.id}>
                <button
                  type="button"
                  onClick={() => openItem(n)}
                  className={`flex w-full gap-3 px-4 py-3 text-left hover:bg-gray-50 ${n.read ? '' : 'bg-blue-50/40'}`}
                >
                  <span className={`mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full ${tone}`}>
                    <Icon className="size-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className={`block text-sm ${n.read ? 'text-gray-700' : 'font-medium text-gray-900'}`}>{n.title}</span>
                    {n.message && <span className="block truncate text-xs text-gray-500">{n.message}</span>}
                    <span className="mt-0.5 block text-[11px] text-gray-400">{timeAgo(n.createdAt)}</span>
                  </span>
                  {!n.read && <span className="mt-2 size-2 shrink-0 rounded-full bg-blue-600" aria-label="Unread" />}
                </button>
              </li>
            );
          })}
        </ul>
      </PopoverContent>
    </Popover>
  );
};

export default NotificationBell;
