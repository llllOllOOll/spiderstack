/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{zig,html}",
    "./templates/**/*.zig",
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('daisyui'),
  ],
  daisyui: {
    themes: ["light", "dark"],
    darkTheme: "dark",
    base: true,
    styled: true,
    utils: true,
  },
}
