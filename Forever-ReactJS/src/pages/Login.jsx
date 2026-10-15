//Login.jsx
import { useContext, useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../api/client";
import { ShopContext } from "../context/ShopContext";

const TITLES = {
  login: 'Login',
  signup: 'Sign Up',
  verify: 'Verify Email',
  forgot: 'Forgot Password',
  reset: 'Reset Password',
};

const inputClass = "w-full px-3 py-2 border border-gray-800";

const Login = () => {
  const { startSession, navigate } = useContext(ShopContext);
  const location = useLocation();
  const from = location.state?.from || '/';

  const [mode, setMode] = useState('login');
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ name: '', email: '', password: '', otp: '', newPassword: '' });
  const [cooldown, setCooldown] = useState(0);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  const goTo = (next) => {
    setMode(next);
    if (next === 'verify' || next === 'reset') setCooldown(60);
  };

  const run = async (action) => {
    setBusy(true);
    try {
      await action();
    } catch (e) {
      if (e.code === 'EMAIL_NOT_VERIFIED') {
        toast.info(e.message);
        goTo('verify');
      } else {
        toast.error(e.message);
      }
    } finally {
      setBusy(false);
    }
  };

  const onSubmitHandler = (event) => {
    event.preventDefault();
    const email = form.email.trim();
    run(async () => {
      switch (mode) {
        case 'signup':
          await api.register({ name: form.name.trim(), email, password: form.password });
          toast.success('We sent a verification code to your email');
          goTo('verify');
          break;
        case 'verify': {
          await startSession(await api.verifyEmail({ email, otp: form.otp.trim() }));
          toast.success('Email verified. Welcome!');
          navigate(from, { replace: true });
          break;
        }
        case 'forgot':
          await api.forgotPassword({ email });
          toast.success('If the account exists, a reset code was sent');
          goTo('reset');
          break;
        case 'reset':
          await api.resetPassword({ email, otp: form.otp.trim(), newPassword: form.newPassword });
          toast.success('Password updated, please log in');
          setForm((f) => ({ ...f, password: '', otp: '', newPassword: '' }));
          setMode('login');
          break;
        default:
          await startSession(await api.login({ email, password: form.password }));
          navigate(from, { replace: true });
      }
    });
  };

  const resend = () =>
    run(async () => {
      await api.resendOtp({ email: form.email.trim(), purpose: mode === 'reset' ? 'RESET_PASSWORD' : 'VERIFY_EMAIL' });
      toast.success('A new code was sent');
      setCooldown(60);
    });

  const submitLabel = { login: 'Sign In', signup: 'Sign Up', verify: 'Verify', forgot: 'Send Code', reset: 'Reset Password' }[mode];

  return (
    <form onSubmit={onSubmitHandler} className="flex flex-col items-center w-[90%] sm:max-w-96 m-auto mt-14 gap-4 text-gray-700">
      <div className="inline-flex items-center gap-2 mb-2 mt-10">
        <p className="prata-regular text-3xl">{TITLES[mode]}</p>
        <hr className="border-none h-1.5 w-8 bg-gray-800" />
      </div>

      {mode === 'signup' && (
        <input type="text" className={inputClass} placeholder="Name" required value={form.name} onChange={set('name')} />
      )}

      {mode === 'verify' || mode === 'reset' ? (
        <p className="text-sm text-center text-gray-600">
          Enter the 6-digit code sent to <b>{form.email}</b>
        </p>
      ) : (
        <input type="email" className={inputClass} placeholder="Email" required value={form.email} onChange={set('email')} />
      )}

      {(mode === 'login' || mode === 'signup') && (
        <input type="password" className={inputClass} placeholder="Password" required minLength={mode === 'signup' ? 8 : undefined}
          value={form.password} onChange={set('password')} />
      )}

      {(mode === 'verify' || mode === 'reset') && (
        <input type="text" inputMode="numeric" pattern="\d{6}" maxLength={6} required autoFocus placeholder="000000"
          className={`${inputClass} text-center text-2xl tracking-[0.5em]`} value={form.otp}
          onChange={(e) => setForm((f) => ({ ...f, otp: e.target.value.replace(/\D/g, '') }))} />
      )}

      {mode === 'reset' && (
        <input type="password" className={inputClass} placeholder="New password (min 8 characters)" required minLength={8}
          value={form.newPassword} onChange={set('newPassword')} />
      )}

      {(mode === 'login' || mode === 'signup') && (
        <div className="w-full flex justify-between text-sm mt-[8px]">
          <p onClick={() => setMode('forgot')} className="cursor-pointer">Forget your password?</p>
          {mode === 'login'
            ? <p onClick={() => setMode('signup')} className="cursor-pointer">Create Account</p>
            : <p onClick={() => setMode('login')} className="cursor-pointer">Login Here</p>}
        </div>
      )}

      {(mode === 'verify' || mode === 'reset') && (
        <button type="button" onClick={resend} disabled={cooldown > 0 || busy} className="text-sm underline disabled:no-underline disabled:text-gray-400">
          {cooldown > 0 ? `Resend code in ${cooldown}s` : 'Resend code'}
        </button>
      )}

      {mode === 'forgot' && (
        <p onClick={() => setMode('login')} className="w-full text-sm cursor-pointer">Back to login</p>
      )}

      <button disabled={busy} className="text-white bg-black px-9 py-2 font-medium mt-2 disabled:bg-gray-400">
        {busy ? 'Please wait...' : submitLabel}
      </button>
    </form>
  );
};

export default Login;
