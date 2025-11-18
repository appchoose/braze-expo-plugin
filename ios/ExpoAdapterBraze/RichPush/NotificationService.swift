#if canImport(BrazeNotificationService)
  import BrazeNotificationService
  import UserNotifications

  #if canImport(BrazeKit) && canImport(ActivityKit)
    import BrazeKit
    import ActivityKit

    class NotificationService: UNNotificationServiceExtension {
      override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
      ) {
        // Handle Live Activity registration first if needed
        if shouldHandleLiveActivity(request: request) {
          handleLiveActivityRegistration(request: request)
        }
        
        // Handle standard Braze notifications
        if brazeHandle(request: request, contentHandler: contentHandler) {
          return
        }
        
        // Fallback: just pass through the content
        contentHandler(request.content)
      }
      
      /// Check if this notification should trigger Live Activity registration
      private func shouldHandleLiveActivity(request: UNNotificationRequest) -> Bool {
        let userInfo = request.content.userInfo
        return userInfo["activityType"] != nil && userInfo["userId"] != nil
      }
      
      /// Handle Live Activity push-to-start registration via Braze
      @available(iOS 17.0, *)
      private func handleLiveActivityRegistration(request: UNNotificationRequest) {
        guard let userInfo = request.content.userInfo as? [String: Any],
              let activityType = userInfo["activityType"] as? String,
              let userId = userInfo["userId"] as? String else {
          print("[NotificationService] Missing required fields for Live Activity registration")
          return
        }
        
        guard let braze = configureBraze(userId: userId) else {
          print("[NotificationService] Failed to configure Braze")
          return
        }
        
        // Get activity attributes from Info.plist
        guard let activityAttributes = getActivityAttributesFromConfig() else {
          print("[NotificationService] No activity attributes configured")
          return
        }
        
        // Register the activity type if it's in the configured list
        if activityAttributes.contains(activityType) {
          // The actual registration will be done in NotificationService+LiveActivity.swift
          // We call registerPushToStart which should be implemented in the extension
          do {
            try registerPushToStart(braze: braze, activityType: activityType)
            print("[NotificationService] Successfully registered push-to-start for activity type: \(activityType)")
          } catch {
            print("[NotificationService] Failed to register push-to-start: \(error.localizedDescription)")
          }
        } else {
          print("[NotificationService] Activity type '\(activityType)' not found in configured attributes")
        }
      }
      
      /// Get activity attributes from Info.plist configuration
      private func getActivityAttributesFromConfig() -> [String]? {
        guard let plistDict = Bundle.main.infoDictionary,
              let brazeConfig = plistDict["Braze"] as? [String: Any],
              let activityAttributes = brazeConfig["LiveActivityAttributes"] as? [String] else {
          return nil
        }
        return activityAttributes
      }
      
      /// Configure Braze instance with API key and endpoint from Info.plist
      private func configureBraze(userId: String) -> Braze? {
        guard let plistDict = Bundle.main.infoDictionary,
              let brazeConfig = plistDict["Braze"] as? [String: Any],
              let apiKey = brazeConfig["ApiKey"] as? String,
              let endpoint = brazeConfig["Endpoint"] as? String else {
          print("[NotificationService] Missing Braze configuration in Info.plist")
          return nil
        }
        
        let configuration = Braze.Configuration(apiKey: apiKey, endpoint: endpoint)
        
        // Set log level if available
        if let logLevel = brazeConfig["LogLevel"] as? Int {
          configuration.logger.level = Braze.Logger.Level(rawValue: logLevel) ?? .info
        } else {
          configuration.logger.level = .info
        }
        
        let braze = Braze(configuration: configuration)
        braze.changeUser(userId: userId)
        return braze
      }
      
      /// Register push-to-start for the specified Live Activity type
      /// This method should be implemented in NotificationService+LiveActivity.swift extension
      @available(iOS 17.0, *)
      func registerPushToStart(braze: Braze, activityType: String) throws {
        // Default implementation - should be overridden in extension
        throw NSError(
          domain: "BrazeExpoPlugin",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "registerPushToStart must be implemented in NotificationService+LiveActivity.swift"]
        )
      }
    }
  #else
    class NotificationService: UNNotificationServiceExtension {
      override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
      ) {
        // Handle standard Braze notifications
        if brazeHandle(request: request, contentHandler: contentHandler) {
          return
        }
        
        // Fallback: just pass through the content
        contentHandler(request.content)
      }
    }
  #endif
#endif
