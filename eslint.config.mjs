import nextVitals from "eslint-config-next/core-web-vitals";

export default [
  ...nextVitals,
  {
    ignores: [".next/**", ".test-dist/**", "node_modules/**", "next-env.d.ts"]
  }
];
