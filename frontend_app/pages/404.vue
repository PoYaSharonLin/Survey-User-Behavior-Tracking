<template>
  <div class="not-found">
    <h1>404</h1>
    <p>Page not found.</p>
    <a href="/survey">Back to Survey</a>
  </div>
</template>

<script>
export default { name: 'NotFound' };
</script>

<style scoped>
.not-found {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  font-family: 'Inter', sans-serif;
  color: #888;
}
.not-found h1 { font-size: 5rem; font-weight: 900; color: #6c63ff; }
.not-found p  { font-size: 1.2rem; margin: 8px 0 24px; }
.not-found a  { color: #6c63ff; text-decoration: none; font-weight: 600; }
.not-found a:hover { text-decoration: underline; }
</style>
