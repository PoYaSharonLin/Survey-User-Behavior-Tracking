const { merge } = require('webpack-merge');
const common = require('./webpack.common');
const path = require('path');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

module.exports = merge(common, {
    mode: 'development',
    devServer: {
        static: './dist',
        historyApiFallback: true,
        hot: true,
        host: '0.0.0.0',
        allowedHosts: 'all',
        devMiddleware: {
            writeToDisk: true,
        },
        proxy: [
            {
                context: ['/api'],
                target: 'http://localhost:9292',
                changeOrigin: true,
            }
        ]
    },
    output: {
        path: path.resolve(__dirname, '../dist'),
        filename: '[name].bundle.js'
    },
    plugins: [
        new CleanWebpackPlugin(),
    ]
});
