import { useContext, useRef, useState } from 'react';
import { toast } from 'react-toastify';
import { api } from '../api/client';
import Title from '../components/Title';
import { ShopContext } from '../context/ShopContext';
import useUnsavedChanges from '../components/useUnsavedChanges';
import { text, validate, z } from '@/lib/validation';

// Same rules as UserDtos.UpdateProfileRequest and UserDtos.ChangePasswordRequest on the API.
const profileSchema = z.object({
  name: text('Name', 120),
  phone: z.string().trim().max(40, 'Phone must be 40 characters or fewer'),
});
const passwordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string()
    .min(1, 'New password is required')
    .min(8, 'Password must be 8-72 characters')
    .max(72, 'Password must be 8-72 characters'),
});

const focusFirstError = (formRef) =>
  requestAnimationFrame(() => formRef.current?.querySelector('[aria-invalid="true"]')?.focus());

// Validation state for one form: errors only show once it has been submitted, then update while typing.
const useFormErrors = (schema) => {
  const [errors, setErrors] = useState({});
  const [submitted, setSubmitted] = useState(false);
  return {
    errors,
    setErrors,
    revalidate: (values) => { if (submitted) setErrors(validate(schema, values).errors); },
    check: (values) => {
      setSubmitted(true);
      const { data, errors: found } = validate(schema, values);
      setErrors(found);
      return data;
    },
    reset: () => { setErrors({}); setSubmitted(false); },
  };
};

const Profile = () => {
  const { user, setUser } = useContext(ShopContext);
  const [profile, setProfile] = useState({ name: user?.name || '', phone: user?.phone || '' });
  const [passwords, setPasswords] = useState({ currentPassword: '', newPassword: '' });
  const [saving, setSaving] = useState(false);
  const profileForm = useFormErrors(profileSchema);
  const passwordForm = useFormErrors(passwordSchema);
  const profileRef = useRef(null);
  const passwordRef = useRef(null);
  // Edited name/phone or a half-typed password change would be lost by leaving the page.
  const dirty = profile.name !== (user?.name || '') || profile.phone !== (user?.phone || '')
    || Boolean(passwords.currentPassword || passwords.newPassword);
  const { dialog: leaveDialog } = useUnsavedChanges(dirty);

  const editProfile = (key) => (e) => {
    const next = { ...profile, [key]: e.target.value };
    setProfile(next);
    profileForm.revalidate(next);
  };
  const editPasswords = (key) => (e) => {
    const next = { ...passwords, [key]: e.target.value };
    setPasswords(next);
    passwordForm.revalidate(next);
  };

  const showServerErrors = (error, form, ref) => {
    toast.error(error.message);
    if (error.fieldErrors) {
      form.setErrors(error.fieldErrors);
      focusFirstError(ref);
    }
  };

  const saveProfile = async (event) => {
    event.preventDefault();
    if (!profileForm.check(profile)) {
      focusFirstError(profileRef);
      return;
    }
    setSaving(true);
    try {
      const updated = await api.updateProfile(profile);
      setUser(updated);
      toast.success('Profile updated');
    } catch (error) {
      showServerErrors(error, profileForm, profileRef);
    } finally {
      setSaving(false);
    }
  };

  const changePassword = async (event) => {
    event.preventDefault();
    if (!passwordForm.check(passwords)) {
      focusFirstError(passwordRef);
      return;
    }
    setSaving(true);
    try {
      await api.changePassword(passwords);
      setPasswords({ currentPassword: '', newPassword: '' });
      passwordForm.reset();
      toast.success('Password changed');
    } catch (error) {
      showServerErrors(error, passwordForm, passwordRef);
    } finally {
      setSaving(false);
    }
  };

  const fieldClass = (invalid) =>
    `w-full rounded border px-3 py-2.5 outline-none ${invalid ? 'border-red-500 focus:border-red-600' : 'border-gray-300 focus:border-gray-700'}`;

  // Props linking an input to its inline error message, plus the message itself.
  const errorProps = (errors, key) => ({
    'aria-invalid': errors[key] ? true : undefined,
    'aria-describedby': errors[key] ? `profile-${key}-error` : undefined,
  });
  const errorText = (errors, key) => errors[key] && (
    <span id={`profile-${key}-error`} className="mt-1 block text-sm text-red-600">{errors[key]}</span>
  );

  const pErr = profileForm.errors;
  const pwErr = passwordForm.errors;

  return (
    <div className="border-t py-14">
      <div className="mb-8 text-2xl"><Title text1="my" text2="Profile" /></div>
      <div className="grid gap-8 lg:grid-cols-2">
        <form ref={profileRef} noValidate onSubmit={saveProfile} className="rounded-lg border p-6">
          <h2 className="mb-1 text-lg font-medium">Personal details</h2>
          <p className="mb-6 text-sm text-gray-500">Update the information used on your account.</p>
          <label className="mb-4 block text-sm">Name
            <input className={`${fieldClass(pErr.name)} mt-1`} value={profile.name}
              onChange={editProfile('name')} maxLength={120} {...errorProps(pErr, 'name')} />
            {errorText(pErr, 'name')}
          </label>
          <label className="mb-4 block text-sm">Email
            <input className={`${fieldClass(false)} mt-1 bg-gray-50 text-gray-500`} value={user?.email || ''} disabled />
          </label>
          <label className="mb-6 block text-sm">Phone
            <input className={`${fieldClass(pErr.phone)} mt-1`} value={profile.phone}
              onChange={editProfile('phone')} maxLength={40} placeholder="Optional" {...errorProps(pErr, 'phone')} />
            {errorText(pErr, 'phone')}
          </label>
          <button disabled={saving} className="bg-black px-7 py-3 text-sm text-white disabled:opacity-50">
            {saving ? 'Saving...' : 'Save profile'}
          </button>
        </form>

        <form ref={passwordRef} noValidate onSubmit={changePassword} className="rounded-lg border p-6">
          <h2 className="mb-1 text-lg font-medium">Security</h2>
          <p className="mb-6 text-sm text-gray-500">Choose a password with at least 8 characters.</p>
          <label className="mb-4 block text-sm">Current password
            <input type="password" className={`${fieldClass(pwErr.currentPassword)} mt-1`} value={passwords.currentPassword}
              onChange={editPasswords('currentPassword')} {...errorProps(pwErr, 'currentPassword')} />
            {errorText(pwErr, 'currentPassword')}
          </label>
          <label className="mb-6 block text-sm">New password
            <input type="password" className={`${fieldClass(pwErr.newPassword)} mt-1`} value={passwords.newPassword}
              onChange={editPasswords('newPassword')} maxLength={72} {...errorProps(pwErr, 'newPassword')} />
            {errorText(pwErr, 'newPassword')}
          </label>
          <button disabled={saving} className="border border-black px-7 py-3 text-sm disabled:opacity-50">
            Change password
          </button>
        </form>
      </div>
      {leaveDialog}
    </div>
  );
};

export default Profile;
