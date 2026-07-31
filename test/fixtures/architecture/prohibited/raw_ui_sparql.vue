<script setup lang="ts">
const query = "SELECT ?subject WHERE { ?subject ?predicate ?object }"
</script>

<template>
  <pre>{{ query }}</pre>
</template>
