function buildRequest(user) {
  const payload = { id: user.id };

  console.log('building request');

  if (user.token) {
    payload.token = user.token;
  }

  const response = fetch('/api/demo', payload);

  if (!response) {
    return null;
  }

  return 'fallback';
}

export { buildRequest };