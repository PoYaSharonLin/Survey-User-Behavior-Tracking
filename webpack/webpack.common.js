
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const { VueLoaderPlugin } = require('vue-loader');
const AutoImport = require('unplugin-auto-import/webpack');
const Components = require('unplugin-vue-components/webpack');
const { ElementPlusResolver } = require('unplugin-vue-components/resolvers');
const webpack = require('webpack');
const dotenv = require('dotenv');

const __base = path.resolve(__dirname, '..');
const __src = path.resolve(__base, 'frontend_app');

dotenv.config({ path: path.resolve(__base, 'frontend_app', '.env.local') });

module.exports = {
    entry: path.resolve(__src, 'main.js'),

    output: {
        filename: '[name].bundle.js',
        path: path.resolve(__base, 'dist'),
        clean: true,
        publicPath: '/',
    },

    plugins: [
        new HtmlWebpackPlugin({
            title: 'Survey',
            template: path.resolve(__src, 'templates', 'index.html'),
        }),
        new VueLoaderPlugin(),
        AutoImport({
            resolvers: [ElementPlusResolver()],
        }),
        Components({
            resolvers: [ElementPlusResolver()],
        }),
        new webpack.DefinePlugin({
            'process.env': JSON.stringify(process.env),
            __VUE_OPTIONS_API__: true,
            __VUE_PROD_DEVTOOLS__: false,
        })
    ],

    resolve: {
        alias: {
            '@': __src,
        },
    },

    module: {
        rules: [
            {
                test: /\.vue$/,
                loader: 'vue-loader'
            },
            {
                test: /\.css$/,
                use: ['vue-style-loader', 'css-loader']
            },
            {
                test: /\.(png|jpg|gif|svg)$/,
                type: 'asset/resource'
            },
        ]
    }
};
