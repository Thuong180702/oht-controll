// Cloudflare Pages Function: /api/auth/password
// Handles GET, POST, and DELETE requests for account & password synchronization across devices.

function getDefaultPassword(username) {
  if (username && username.trim().toLowerCase() === 'admin') {
    return 'admin@1234';
  }
  return 'Thaco@1234';
}

export async function onRequestGet(context) {
  const { env, request } = context;
  const url = new URL(request.url);
  const action = url.searchParams.get('action');

  // Handle syncing full accounts list across devices
  if (action === 'accounts') {
    let accountsListJson = null;
    if (env.AUTH_STORE) {
      try {
        accountsListJson = await env.AUTH_STORE.get('oht_user_accounts_list');
      } catch (e) {
        console.error('Error reading accounts list from KV:', e);
      }
    }
    return new Response(
      JSON.stringify({
        success: true,
        accounts: accountsListJson ? JSON.parse(accountsListJson) : null,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store, no-cache, must-revalidate',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }

  const username = url.searchParams.get('username') || 'Thaco';
  const cleanUser = username.trim();
  const lowerUser = cleanUser.toLowerCase();

  let password = getDefaultPassword(cleanUser);
  if (env.AUTH_STORE) {
    try {
      let stored = await env.AUTH_STORE.get(`user_password_${cleanUser}`);
      if (!stored) {
        stored = await env.AUTH_STORE.get(`user_password_${lowerUser}`);
      }
      if (stored && stored.trim().length > 0) {
        password = stored;
      }
    } catch (e) {
      console.error('Error reading KV AUTH_STORE:', e);
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      username: cleanUser,
      password: password,
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store, no-cache, must-revalidate',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    }
  );
}

export async function onRequestPost(context) {
  const { env, request } = context;
  const url = new URL(request.url);
  const action = url.searchParams.get('action');

  try {
    const body = await request.json();

    // Handle syncing full accounts list from Admin
    if (action === 'accounts' || body.accountsList) {
      if (env.AUTH_STORE && body.accountsList) {
        await env.AUTH_STORE.put('oht_user_accounts_list', JSON.stringify(body.accountsList));
      }
      return new Response(
        JSON.stringify({ success: true, message: 'Accounts list synchronized to Cloudflare KV' }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    const username = body.username || 'Thaco';
    const cleanUser = username.trim();
    const lowerUser = cleanUser.toLowerCase();
    const oldPassword = body.oldPassword;
    const newPassword = body.newPassword;
    const force = body.force === true; // Admin bypass flag

    if (!newPassword || newPassword.trim().length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'New password cannot be empty' }),
        { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    let currentPassword = getDefaultPassword(cleanUser);

    if (env.AUTH_STORE) {
      let stored = await env.AUTH_STORE.get(`user_password_${cleanUser}`);
      if (!stored) {
        stored = await env.AUTH_STORE.get(`user_password_${lowerUser}`);
      }
      if (stored && stored.trim().length > 0) {
        currentPassword = stored;
      }
    }

    // Unless force=true (Admin creation/reset), verify old password
    if (!force && oldPassword && oldPassword !== currentPassword) {
      return new Response(
        JSON.stringify({ success: false, message: 'Old password does not match' }),
        { status: 401, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      );
    }

    if (env.AUTH_STORE) {
      await env.AUTH_STORE.put(`user_password_${cleanUser}`, newPassword);
      await env.AUTH_STORE.put(`user_password_${lowerUser}`, newPassword);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Password updated and synchronized successfully',
        username: cleanUser,
        password: newPassword,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, message: e.message || 'Internal Server Error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    );
  }
}

export async function onRequestDelete(context) {
  const { env, request } = context;
  const url = new URL(request.url);
  const username = url.searchParams.get('username');

  if (!username || username.trim().length === 0) {
    return new Response(
      JSON.stringify({ success: false, message: 'Username is required' }),
      { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    );
  }

  const cleanUser = username.trim();
  const lowerUser = cleanUser.toLowerCase();

  if (env.AUTH_STORE) {
    try {
      await env.AUTH_STORE.delete(`user_password_${cleanUser}`);
      await env.AUTH_STORE.delete(`user_password_${lowerUser}`);
    } catch (e) {
      console.error('Error deleting key from KV:', e);
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: `User ${cleanUser} deleted from Cloudflare KV`,
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    }
  );
}

export async function onRequestOptions() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
