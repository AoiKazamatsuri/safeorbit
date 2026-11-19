// Cross-module consumers import only this public entry point.
export { CareApiModule } from '../care-api.module';
export type { PossibleDestination } from '../location-view';
export { CareEvents, DestinationRequest, DispositionSubmitted, LocationsStored, StateChanged, StateChangeType } from '../care-events';
export { CareStore, SafeZone, StoredFix, TrackerRecord, TripChange } from '../care-store';
export { distanceMeters, distanceToPolylineMeters, GeoPoint, isValidPoint } from '../geo';
export {
  ActionKind, ActionWrite, CaregiverSettings, DEFAULT_CAREGIVER_SETTINGS, PushJob, PushRecipient, RiskActivity,
  RiskEventRecord, RiskRecords, RiskWrite,
} from '../risk-records';
export { Records } from '../records';

export { DeviceAuth } from '../device-auth';
export { ChatQueries, ChatQuery, Citation, QueryResult } from '../chat-queries';
