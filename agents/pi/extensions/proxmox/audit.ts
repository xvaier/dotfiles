import { readFileSync } from "node:fs";
import { command, type SSHResult } from "./core.ts";

export const AUDIT_SECTIONS = ["system", "disks", "boot", "guests", "backups", "mounts", "recovery"] as const;
export type AuditSection = typeof AUDIT_SECTIONS[number];
interface Probe { status: "ok" | "unavailable"; data?: unknown; reason?: string; exitCode?: number }
export interface AuditReport {
  collectedAt: number;
  sections: Record<string, { status: "ok" | "partial"; probes: Record<string, Probe> }>;
}
const script = readFileSync(new URL("./audit.py", import.meta.url), "utf8");

export function auditCommand(sections: AuditSection[] = ["system", "guests"]): string {
  if (!sections.length || sections.some(section => !AUDIT_SECTIONS.includes(section))) throw new Error("Choose valid audit sections");
  return command(["python3", "-c", script, JSON.stringify([...new Set(sections)])]);
}

export function auditResult(result: SSHResult): { audit?: AuditReport; summary: string } {
  if (result.outcome !== "completed") return { summary: "Audit could not complete." };
  try {
    const report: AuditReport = JSON.parse(result.fullOutputPath ? readFileSync(result.fullOutputPath, "utf8") : result.output);
    const summary = Object.entries(report.sections).map(([name, section]) => {
      const failed = Object.values(section.probes).filter(probe => probe.status !== "ok").length;
      return `${name}: ${section.status}${failed ? ` (${failed} unavailable probes)` : ""}`;
    }).join(" · ");
    // Keep structured tool output bounded too. Large reports remain in the private full-output file.
    if (result.fullOutputPath) {
      for (const section of Object.values(report.sections)) {
        for (const probe of Object.values(section.probes)) {
          if (probe.data !== undefined) {
            delete probe.data;
            probe.reason = "Data retained in full-output file";
          }
        }
      }
    }
    return { audit: report, summary };
  } catch {
    return { summary: "Invalid audit response; inspect command output." };
  }
}
