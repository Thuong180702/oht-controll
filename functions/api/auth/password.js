// Cloudflare Pages Function: /api/auth/password
// Automatically handles GET and POST requests for password synchronization across devices.

function getDefaultPassword(username) {
  if (username && username.trim().toLowerCase() === 'admin') {
    return 'admin@1234';
  }
  return 'Thaco@1234';
}

export async function onRequestGet(context) {
  const { env, request } = context;
  const url = new URL(request.url);
  const username = url.searchParams.get('username') || 'Thaco';
  const cleanUser = username.trim();
  const lowerUser = cleanUser.toLowerCase();

  let password = getDefaultPassword(cleanUser);
  if (env.AUTH_STORE) {
    try {
      // Check exact username key or lowercase key
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
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    }
  );
}

export async function onRequestPost(context) {
  const { env, request } = context;

  try {
    const body = await request.json();
    const username = body.username || 'Thaco';
    const cleanUser = username.trim();
    const lowerUser = cleanUser.toLowerCase();
    const oldPassword = body.oldPassword;
    const newPassword = body.newPassword;

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

    if (oldPassword && oldPassword !== currentPassword) {
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

export async function onRequestOptions() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
