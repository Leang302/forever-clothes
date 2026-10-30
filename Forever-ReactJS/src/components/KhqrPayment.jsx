import { useCallback, useEffect, useRef, useState } from "react";
import { API_URL, api, session } from "../api/client";

const secondsUntil = (instant) => Math.max(0, Math.round((new Date(instant) - Date.now()) / 1000));
const clock = (seconds) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

/**
 * KHQR card for a pending order. Opens an SSE stream to get a real-time "paid" push from the server,
 * or cancels the order when the customer gives up / the code expires (onClosed('cancelled' | 'expired')).
 */
export default function KhqrPayment({ payment, onPaid, onClosed }) {
  const [secondsLeft, setSecondsLeft] = useState(() => secondsUntil(payment.expiresAt));
  const [closing, setClosing] = useState(false);
  // Set once the dialog has an outcome so SSE and cancel never both fire.
  const finished = useRef(false);

  const finish = useCallback((paid, reason) => {
    if (finished.current) return;
    finished.current = true;
    if (paid) onPaid();
    else onClosed(reason);
  }, [onPaid, onClosed]);

  // SSE: server pushes a "paid" event the moment Bakong confirms payment.
  useEffect(() => {
    const token = session.getToken();
    const url = new URL(`${API_URL}/api/khqr/${payment.orderId}/events`, window.location.origin);
    if (token) url.searchParams.set('token', token);
    const es = new EventSource(url.toString());
    es.addEventListener('paid', () => {
      es.close();
      finish(true);
    });
    // onerror fires on normal close too; the browser auto-reconnects until we call close().
    return () => es.close();
  }, [payment.orderId, finish]);

  const cancel = useCallback(async (reason) => {
    if (finished.current || closing) return;
    setClosing(true);
    try {
      // The API checks Bakong first, so a payment made at the last second is kept, not cancelled.
      const result = await api.cancelKhqr(payment.orderId);
      finish(result.paid, reason);
    } catch {
      finish(false, reason);
    }
  }, [closing, finish, payment.orderId]);

  useEffect(() => {
    const timer = setInterval(() => setSecondsLeft(secondsUntil(payment.expiresAt)), 1000);
    return () => clearInterval(timer);
  }, [payment.expiresAt]);

  useEffect(() => {
    if (secondsLeft === 0) cancel('expired');
  }, [secondsLeft, cancel]);

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/60 px-4">
      <div role="dialog" aria-modal="true" aria-labelledby="khqr-title" className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-2xl">
        <div className="flex items-center justify-between">
          <h2 id="khqr-title" className="text-xl font-semibold text-gray-900">Scan to pay</h2>
          <button type="button" onClick={() => cancel('cancelled')} disabled={closing} className="h-9 w-9 rounded-full text-xl text-gray-500 hover:bg-gray-100" aria-label="Cancel payment">×</button>
        </div>
        <div className="mx-auto mt-5 w-64 overflow-hidden rounded-xl text-left shadow-[0_2px_16px_rgba(0,0,0,0.12)]">
          <div className="bg-[#E1232E] py-2.5 text-center text-lg font-bold tracking-wider text-white">KHQR</div>
          <div className="px-5 pb-2 pt-4">
            <p className="text-sm text-gray-600">{payment.merchantName}</p>
            <p className="text-2xl font-semibold text-gray-900">
              {Number(payment.amount).toFixed(2)} <span className="text-sm font-normal text-gray-500">{payment.currency}</span>
            </p>
          </div>
          <div className="mx-5 border-t border-dashed border-gray-300" />
          <img src={payment.qrImage} alt="KHQR payment code" className="mx-auto h-56 w-56 p-3" />
        </div>
        <p className="mt-4 text-sm text-gray-600">Scan with Bakong or any Cambodian banking app (ABA, ACLEDA, Wing…).</p>
        <p className="mt-1 text-xs text-gray-400" aria-live="polite">
          {closing ? 'Closing…' : `Waiting for payment · code expires in ${clock(secondsLeft)}`}
        </p>
        <button type="button" onClick={() => cancel('cancelled')} disabled={closing} className="mt-5 w-full rounded-lg border px-5 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:text-gray-400">Cancel payment</button>
      </div>
    </div>
  );
}
