// Turbo navigation loading indicator
document.addEventListener("turbo:click", () => {
  document.body.classList.add("nav-loading");
});

document.addEventListener("turbo:load", () => {
  document.body.classList.remove("nav-loading");
});

document.addEventListener("turbo:before-fetch-response", () => {
  document.body.classList.remove("nav-loading");
});
