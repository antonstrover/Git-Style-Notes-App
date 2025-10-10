"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { ArrowRight, GitBranch, Users, Search, Lock, Zap, History } from "lucide-react";
import { AnimatedBackground } from "./animated-background";
import { FeatureCard } from "./feature-card";
import { VersionTimeline } from "./version-timeline";
import { GradientButton } from "./gradient-button";
import { Button } from "@/components/ui/button";

export function LandingPage() {
  const features = [
    {
      icon: GitBranch,
      title: "Git-Style Versioning",
      description: "Every edit creates an immutable version. Track changes, compare diffs, and never lose your work.",
    },
    {
      icon: Users,
      title: "Real-Time Collaboration",
      description: "Work together seamlessly with live presence tracking and conflict-free merging.",
    },
    {
      icon: Search,
      title: "Semantic Search",
      description: "AI-powered search across all your notes and versions with intelligent context understanding.",
    },
    {
      icon: Lock,
      title: "Granular Permissions",
      description: "Control access with public, private, and shared visibility levels for every note.",
    },
    {
      icon: Zap,
      title: "Lightning Fast",
      description: "Built for performance with real-time updates and optimized search indexing.",
    },
    {
      icon: History,
      title: "Complete History",
      description: "Full audit trail of all changes with the ability to revert to any previous version.",
    },
  ];

  const steps = [
    {
      number: "01",
      title: "Create & Write",
      description: "Start a new note and write your content using our intuitive editor.",
    },
    {
      number: "02",
      title: "Auto-Version",
      description: "Every save creates an immutable version, building your complete history.",
    },
    {
      number: "03",
      title: "Collaborate & Share",
      description: "Share notes with teammates and collaborate in real-time with conflict resolution.",
    },
  ];

  return (
    <div className="relative min-h-screen overflow-hidden bg-background">
      <AnimatedBackground />

      {/* Hero Section */}
      <section className="relative px-6 py-20 md:py-32">
        <div className="container mx-auto max-w-6xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="text-center"
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ duration: 0.4, delay: 0.1 }}
              className="mb-6 inline-flex items-center gap-2 rounded-md border border-primary/20 bg-primary/10 px-4 py-2 text-sm font-medium text-primary"
            >
              <Zap className="h-4 w-4" />
              <span>Version-Controlled Note-Taking</span>
            </motion.div>

            <h1 className="mb-6 text-5xl font-bold tracking-tight md:text-6xl">
              Your Ideas,
              <br />
              <span className="text-primary">Perfectly Versioned</span>
            </h1>

            <p className="mx-auto mb-8 max-w-2xl text-lg text-muted-foreground">
              A revolutionary note-taking platform with Git-style version control, real-time collaboration,
              and AI-powered search. Never lose a thought, never lose a version.
            </p>

            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: 0.2 }}
              className="flex flex-col items-center justify-center gap-4 sm:flex-row"
            >
              <GradientButton size="lg" href="/auth/register">
                Get Started Free
                <ArrowRight className="ml-2 h-5 w-5" />
              </GradientButton>

              <Button size="lg" variant="outline" asChild>
                <Link href="/auth/login">Sign In</Link>
              </Button>
            </motion.div>

            {/* Stats */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.5, delay: 0.3 }}
              className="mt-16 grid grid-cols-3 gap-8"
            >
              <div>
                <div className="text-3xl font-bold text-primary">100%</div>
                <div className="text-sm text-muted-foreground">Version History</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary">Real-time</div>
                <div className="text-sm text-muted-foreground">Collaboration</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary">AI-Powered</div>
                <div className="text-sm text-muted-foreground">Search</div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* Visual Demo Section */}
      <section className="relative px-6 py-20">
        <div className="container mx-auto max-w-6xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="overflow-hidden rounded-md border border-border bg-card p-8"
          >
            <div className="mb-6 text-center">
              <h2 className="mb-2 text-2xl font-bold">Complete Version Timeline</h2>
              <p className="text-muted-foreground">Track every change, revert anytime</p>
            </div>
            <VersionTimeline />
          </motion.div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="relative px-6 py-20">
        <div className="container mx-auto max-w-6xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="mb-12 text-center"
          >
            <h2 className="mb-4 text-4xl font-bold tracking-tight">How It Works</h2>
            <p className="text-lg text-muted-foreground">
              Three simple steps to version-controlled collaboration
            </p>
          </motion.div>

          <div className="grid gap-8 md:grid-cols-3">
            {steps.map((step, index) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: index * 0.1 }}
                className="relative"
              >
                <div className="rounded-md border border-border bg-card p-6 text-center">
                  <div className="mb-4 inline-flex h-16 w-16 items-center justify-center rounded-md bg-primary/10 text-3xl font-bold text-primary">
                    {step.number}
                  </div>
                  <h3 className="mb-2 text-xl font-semibold">{step.title}</h3>
                  <p className="text-muted-foreground">{step.description}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Features Grid Section */}
      <section className="relative px-6 py-20">
        <div className="container mx-auto max-w-6xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="mb-12 text-center"
          >
            <h2 className="mb-4 text-4xl font-bold tracking-tight">Powerful Features</h2>
            <p className="text-lg text-muted-foreground">
              Everything you need for modern, collaborative note-taking
            </p>
          </motion.div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature, index) => (
              <FeatureCard
                key={feature.title}
                icon={feature.icon}
                title={feature.title}
                description={feature.description}
                index={index}
              />
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="relative px-6 py-20">
        <div className="container mx-auto max-w-4xl">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="relative overflow-hidden rounded-md border border-border bg-card p-12 text-center"
          >
            <div className="relative z-10">
              <h2 className="mb-4 text-4xl font-bold tracking-tight">
                Ready to Transform Your Note-Taking?
              </h2>
              <p className="mb-8 text-lg text-muted-foreground">
                Join thousands of users who never lose a version, never lose an idea.
              </p>

              <div className="flex flex-col items-center justify-center gap-4 sm:flex-row">
                <GradientButton size="lg" href="/auth/register">
                  Start Free Today
                  <ArrowRight className="ml-2 h-5 w-5" />
                </GradientButton>

                <Button size="lg" variant="outline" asChild>
                  <Link href="/auth/login">Sign In</Link>
                </Button>
              </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-border px-6 py-8">
        <div className="container mx-auto max-w-6xl text-center text-sm text-muted-foreground">
          <p>&copy; {new Date().getFullYear()} Versioned Notes. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
}
