export const safetyCategories = ['emergencyAlerts', 'batteryAlerts', 'screenTimeAlerts', 'offlineAlerts', 'missedCheckInAlerts', 'locationSharing'] as const;
export const defaultSafetyPreferences = Object.fromEntries(safetyCategories.map(key => [key, key === 'emergencyAlerts']));
export function activeSafetySlot(data: {status?: unknown; expiresAt?: {toMillis(): number}}, now = Date.now()): boolean {
  return data.status === 'connected' || (data.status === 'pending' && (data.expiresAt?.toMillis() ?? 0) > now);
}
export function validSafetyPreferences(value: unknown, premium: boolean): value is Record<string, boolean> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const entries = Object.entries(value);
  return entries.length === safetyCategories.length && safetyCategories.every(key => key in value) &&
    entries.every(([key, enabled]) => safetyCategories.includes(key as typeof safetyCategories[number]) && typeof enabled === 'boolean' && (premium || key === 'emergencyAlerts' || !enabled));
}
