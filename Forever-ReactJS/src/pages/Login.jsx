//Login.jsx
import { useContext, useEffect, useRef, useState } from "react";
import { useLocation } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../api/client";
import { ShopContext } from "../context/ShopContext";
import { email as emailRule, text, validate, z } from "@/lib/validation";

const TITLES = {
  login: 'Login',
  signup: 'Sign Up',
  verify: 'Verify Email',
  forgot: 'Forgot Password',
  reset: 'Reset Password',
};

// Same rules as AuthDtos on the API (RegisterRequest, LoginRequest, VerifyEmailRequest, ForgotPasswordRequest,
// ResetPasswordRequest).
const requiredPassword = (label) => z.string().min(1, `${label} is required`);
const newPassword = (label) => requiredPassword(label)
  .min(8, 'Password must be 8-72 characters')
  .max(72, 'Password must be 8-72 characters');
const otp = z.string().trim().min(1, 'Enter the code from your email').regex(/^\d{6}$/, 'Enter the 6-digit code');

const SCHEMAS = {
  login: z.object({ email: emailRule, password: requiredPassword('Password') }),
  signup: z.object({
    name: text('Name', 120),
    email: emailRule.max(190, 'Email must be 190 characters or fewer'),
    password: newPassword('Password'),
  }),
  verify: z.object({ email: emailRule, otp }),
  forgot: z.object({ email: emailRule }),
  reset: z.object({ email: emailRule, otp, newPassword: newPassword('New password') }),
};

const inputClass = (invalid) => `w-full px-3 py-2 border ${invalid ? 'border-red-500' : 'border-gray-800'}`;

const Login = () => {
  const { startSession, navigate } = useContext(ShopContext);
  const location = useLocation();
  const from = location.state?.from || '/';
  const formRef = useRef(null);

  const [mode, setMode] = useState('login');
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ name: '', email: '', password: '', otp: '', newPassword: '' });
  const [cooldown, setCooldown] = useState(0);
  const [errors, setErrors] = useState({});
  // Errors only show (and update while typing) once the form has been submitted.
  const [submitted, setSubmitted] = useState(false);

  const update = (key, value) => {
    const next = { ...form, [key]: value };
    setForm(next);
    if (submitted) setErrors(validate(SCHEMAS[mode], next).errors);
  };
  const set = (key) => (e) => update(key, e.target.value);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  const switchMode = (next) => {
    setMode(next);
    setErrors({});
    setSubmitted(false);
  };

  const goTo = (next) => {
    switchMode(next);
    if (next === 'verify' || next === 'reset') setCooldown(60);
  };

  const focusFirstError = () =>
    requestAnimationFrame(() => formRef.current?.querySelector('[aria-invalid="true"]')?.focus());

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
        if (e.fieldErrors) {
          setErrors(e.fieldErrors);
          focusFirstError();
        }
      }
    } finally {
      setBusy(false);
    }
  };

  const onSubmitHandler = (event) => {
    event.preventDefault();
    setSubmitted(true);
    const { data, errors: found } = validate(SCHEMAS[mode], form);
    setErrors(found);
    if (!data) {
      focusFirstError();
      return;
    }
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
          switchMode('login');
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

  // Props linking an input to its inline error message.
  const errorProps = (key) => ({
    'aria-invalid': errors[key] ? true : undefined,
    'aria-describedby': errors[key] ? `login-${key}-error` : undefined,
  });
  const errorText = (key) => errors[key] && (
    <p id={`login-${key}-error`} className="mt-1 text-sm text-red-600">{errors[key]}</p>
  );

  return (
    <form ref={formRef} noValidate onSubmit={onSubmitHandler} className="flex flex-col items-center w-[90%] sm:max-w-96 m-auto mt-14 gap-4 text-gray-700">
      <div className="inline-flex items-center gap-2 mb-2 mt-10">
        <p className="prata-regular text-3xl">{TITLES[mode]}</p>
        <hr className="border-none h-1.5 w-8 bg-gray-800" />
      </div>

      {mode === 'signup' && (
        <div className="w-full">
          <input type="text" className={inputClass(errors.name)} placeholder="Name" maxLength={120}
            value={form.name} onChange={set('name')} {...errorProps('name')} />
          {errorText('name')}
        </div>
      )}

      {mode === 'verify' || mode === 'reset' ? (
        <div className="w-full text-center">
          <p className="text-sm text-gray-600">
            Enter the 6-digit code sent to <b>{form.email}</b>
          </p>
          {errorText('email')}
        </div>
      ) : (
        <div className="w-full">
          <input type="email" className={inputClass(errors.email)} placeholder="Email" maxLength={190}
            value={form.email} onChange={set('email')} {...errorProps('email')} />
          {errorText('email')}
        </div>
      )}

      {(mode === 'login' || mode === 'signup') && (
        <div className="w-full">
          <input type="password" className={inputClass(errors.password)} placeholder="Password"
            value={form.password} onChange={set('password')} {...errorProps('password')} />
          {errorText('password')}
        </div>
      )}

      {(mode === 'verify' || mode === 'reset') && (
        <div className="w-full">
          <input type="text" inputMode="numeric" maxLength={6} autoFocus placeholder="000000"
            className={`${inputClass(errors.otp)} text-center text-2xl tracking-[0.5em]`} value={form.otp}
            onChange={(e) => update('otp', e.target.value.replace(/\D/g, ''))} {...errorProps('otp')} />
          {errorText('otp')}
        </div>
      )}

      {mode === 'reset' && (
        <div className="w-full">
          <input type="password" className={inputClass(errors.newPassword)} placeholder="New password (min 8 characters)"
            value={form.newPassword} onChange={set('newPassword')} {...errorProps('newPassword')} />
          {errorText('newPassword')}
        </div>
      )}

      {(mode === 'login' || mode === 'signup') && (
        <div className="w-full flex justify-between text-sm mt-[8px]">
          <p onClick={() => switchMode('forgot')} className="cursor-pointer">Forget your password?</p>
          {mode === 'login'
            ? <p onClick={() => switchMode('signup')} className="cursor-pointer">Create Account</p>
            : <p onClick={() => switchMode('login')} className="cursor-pointer">Login Here</p>}
        </div>
      )}

      {(mode === 'verify' || mode === 'reset') && (
        <button type="button" onClick={resend} disabled={cooldown > 0 || busy} className="text-sm underline disabled:no-underline disabled:text-gray-400">
          {cooldown > 0 ? `Resend code in ${cooldown}s` : 'Resend code'}
        </button>
      )}

      {mode === 'forgot' && (
        <p onClick={() => switchMode('login')} className="w-full text-sm cursor-pointer">Back to login</p>
      )}

      <button disabled={busy} className="text-white bg-black px-9 py-2 font-medium mt-2 disabled:bg-gray-400">
        {busy ? 'Please wait...' : submitLabel}
      </button>
    </form>
  );
};

export default Login;
