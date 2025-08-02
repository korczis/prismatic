/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./js/**/*.js",
    "../lib/*_web/**/*.*ex",
    "../lib/*_web/**/*.heex",
    "./node_modules/flowbite/**/*.js"
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('flowbite/plugin')
  ],
  darkMode: 'class',
}