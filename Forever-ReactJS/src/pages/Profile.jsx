import { useContext, useState } from 'react';
import { toast } from 'react-toastify';
import { api } from '../api/client';
import Title from '../components/Title';
import { ShopContext } from '../context/ShopContext';

const Profile = () => {
  const { user, setUser } = useContext(ShopContext);
  const [profile, setProfile] = useState({ name: user?.name || '', phone: user?.phone || '' });
  const [passwords, setPasswords] = useState({ currentPassword: '', newPassword: '' });
  const [saving, setSaving] = useState(false);

  const saveProfile = async (event) => {
    event.preventDefault();
    setSaving(true);
    try {
      const updated = await api.updateProfile(profile);
      setUser(updated);
      toast.success('Profile updated');
    } catch (error) {
      toast.error(error.message);
    } finally {
      setSaving(false);
    }
  };

  const changePassword = async (event) => {
    event.preventDefault();
    if (passwords.newPassword.length < 8) {
      toast.error('New password must be at least 8 characters');
      return;
    }
    setSaving(true);
    try {
      await api.changePassword(passwords);
      setPasswords({ currentPassword: '', newPassword: '' });
      toast.success('Password changed');
    } catch (error) {
      toast.error(error.message);
    } finally {
      setSaving(false);
    }
  };

  const fieldClass = 'w-full rounded border border-gray-300 px-3 py-2.5 outline-none focus:border-gray-700';

  return (
    <div className="border-t py-14">
      <div className="mb-8 text-2xl"><Title text1="my" text2="Profile" /></div>
      <div className="grid gap-8 lg:grid-cols-2">
        <form onSubmit={saveProfile} className="rounded-lg border p-6">
          <h2 className="mb-1 text-lg font-medium">Personal details</h2>
          <p className="mb-6 text-sm text-gray-500">Update the information used on your account.</p>
          <label className="mb-4 block text-sm">Name
            <input className={`${fieldClass} mt-1`} value={profile.name}
              onChange={(e) => setProfile({ ...profile, name: e.target.value })} required maxLength={120} />
          </label>
          <label className="mb-4 block text-sm">Email
            <input className={`${fieldClass} mt-1 bg-gray-50 text-gray-500`} value={user?.email || ''} disabled />
          </label>
          <label className="mb-6 block text-sm">Phone
            <input className={`${fieldClass} mt-1`} value={profile.phone}
              onChange={(e) => setProfile({ ...profile, phone: e.target.value })} maxLength={40} placeholder="Optional" />
          </label>
          <button disabled={saving} className="bg-black px-7 py-3 text-sm text-white disabled:opacity-50">
            {saving ? 'Saving...' : 'Save profile'}
          </button>
        </form>

        <form onSubmit={changePassword} className="rounded-lg border p-6">
          <h2 className="mb-1 text-lg font-medium">Security</h2>
          <p className="mb-6 text-sm text-gray-500">Choose a password with at least 8 characters.</p>
          <label className="mb-4 block text-sm">Current password
            <input type="password" className={`${fieldClass} mt-1`} value={passwords.currentPassword}
              onChange={(e) => setPasswords({ ...passwords, currentPassword: e.target.value })} required />
          </label>
          <label className="mb-6 block text-sm">New password
            <input type="password" className={`${fieldClass} mt-1`} value={passwords.newPassword}
              onChange={(e) => setPasswords({ ...passwords, newPassword: e.target.value })} required minLength={8} maxLength={72} />
          </label>
          <button disabled={saving} className="border border-black px-7 py-3 text-sm disabled:opacity-50">
            Change password
          </button>
        </form>
      </div>
    </div>
  );
};

export default Profile;
