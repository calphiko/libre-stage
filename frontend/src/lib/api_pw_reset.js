export const API_URL = import.meta.env.VITE_API_URL;

export { triggerSendPwResetToken } from '$lib/api.js';

export async function verifyPwResetToken(reset_token) {
  const res = await fetch(`${API_URL}/password_reset/verify_reset_token`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reset_token}`
      },
    });
    if (!res.ok) throw new Error('Ungültiger oder abgelaufener Reset-Token');
    return res.json();
}

export async function resetPassword(reset_token, new_password) {
  const res = await fetch(`${API_URL}/password_reset/new_password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reset_token}`
      },
      body: JSON.stringify( {new_password } )
    });
    if (!res.ok) throw new Error('Passwort zurücksetzen fehlgeschlagen');
    return res.json();
}