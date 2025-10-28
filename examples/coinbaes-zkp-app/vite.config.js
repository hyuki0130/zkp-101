import { defineConfig } from 'vite';
import { nodePolyfills } from 'vite-plugin-node-polyfills';

export default defineConfig({
    root: 'src',
    plugins: [
        nodePolyfills(),
    ],
    resolve: {
        alias: {
            // Polyfill pino for browser compatibility
            'pino': 'pino/browser.js',
        },
    },
    optimizeDeps: {
        esbuildOptions: {
            target: 'esnext',
        },
        exclude: ['@noir-lang/noirc_abi', '@noir-lang/acvm_js', '@aztec/bb.js'],
    },
    build: {
        target: 'esnext',
    },
    server: {
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
        },
    },
});
