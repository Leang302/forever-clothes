import { useEffect } from "react";

/** Small yes/no dialog. Escape, clicking outside or the cancel button all mean "no". */
export default function ConfirmDialog({
  title = 'Discard changes?',
  message,
  confirmLabel = 'Discard changes',
  cancelLabel = 'Keep editing',
  onCancel,
  onConfirm,
}) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onCancel();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onCancel]);

  return (
    <div className="fixed inset-0 z-[1100] flex items-center justify-center bg-black/50 px-4"
      onMouseDown={(e) => e.target === e.currentTarget && onCancel()}>
      <div role="alertdialog" aria-modal="true" aria-labelledby="confirm-title" aria-describedby="confirm-message"
        className="w-full max-w-md rounded-lg bg-white p-6 shadow-2xl">
        <h2 id="confirm-title" className="text-lg font-semibold text-gray-900">{title}</h2>
        {message && <p id="confirm-message" className="mt-2 text-sm leading-6 text-gray-600">{message}</p>}
        <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <button type="button" onClick={onCancel} autoFocus
            className="rounded border border-gray-300 px-5 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
            {cancelLabel}
          </button>
          <button type="button" onClick={onConfirm}
            className="rounded bg-red-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-red-700">
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
