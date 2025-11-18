#if canImport(BrazeNotificationService)
  import BrazeNotificationService

  #if canImport(BrazeKit) && canImport(ActivityKit)
    import BrazeKit
    import ActivityKit
    import UserNotifications

    class NotificationService: BrazeNotificationService.NotificationService {
      override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        // Check if Live Activity registration is enabled and handle it first
        if shouldHandleLiveActivity(request: request) {
          handleLiveActivityRegistration(request: request)
        }
        
        // Call parent implementation for standard Braze notification handling
        super.didReceive(request, withContentHandler: contentHandler)
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
      /// Override this method in your app code to register specific ActivityAttributes types
      /// Example:
      /// ```
      /// override func registerPushToStart(braze: Braze, activityType: String) throws {
      ///   switch activityType {
      ///   case "YourActivityType":
      ///     braze.liveActivities.registerPushToStart(
      ///       forType: YourActivityAttributes.self,
      ///       name: activityType
      ///     )
      ///   default:
      ///     throw NSError(...)
      ///   }
      /// }
      /// ```
      @available(iOS 17.0, *)
      func registerPushToStart(braze: Braze, activityType: String) throws {
        // This method should be overridden in the app to register specific ActivityAttributes types
        print("[NotificationService] Live Activity registration for type '\(activityType)' needs to be implemented in app code")
      }
    }
  #else
    class NotificationService: BrazeNotificationService.NotificationService {}
  #endif
#endif
