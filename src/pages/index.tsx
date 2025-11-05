import Head from "next/head";
import { Pixelify_Sans } from "next/font/google";

import dynamic from "next/dynamic";

const pixelify_sans = Pixelify_Sans({ subsets: ["latin"], weight: ['500'], display: 'swap' });

const AppWithoutSSR = dynamic(() => import("@/App"), { ssr: false });

export default function Home() {
    return (
        <>
            <Head>
                <title>OneValley</title>
                <meta name="description" content="A Phaser 3 Next.js project" />
                <link rel="icon" href="/favicon.png" />
            </Head>
            <main className={`${pixelify_sans.className}`}>
                <AppWithoutSSR />
            </main>
        </>
    );
}
