//
//  EndpointFeed.swift
//  Swiftagram
//
//  Created by Stefano Bertagno on 08/03/2020.
//

import Foundation

import ComposableRequest

public extension Endpoint {
    /// A `struct` holding reference to `feed` and `usertags` `Endpoint`s. Requires authentication.
    struct Feed {
        /// The base endpoint.
        private static let base = Endpoint.version1.feed.appendingDefaultHeader()

        /// Stories tray.
        public static let followedStories: ResponseDisposable = base.reels_tray.prepare().locking(Secret.self)
        /// Liked media.
        public static let liked: ResponsePaginated = base.liked.paginating().locking(Secret.self)
        /// All saved media.
        public static let saved: ResponsePaginated = base.saved
            .appending(header: "include_igtv_preview", with: "false")
            .paginating()
            .locking(Secret.self)
        /// Timeline.
        public static let timeline: ResponsePaginated = Endpoint.version1
            .feed
            .timeline
            .appendingDefaultHeader()
            .appending(header: [
                "X-Ads-Opt-Out": "0",
                "X-Google-AD-ID": Device.default.googleAdId.uuidString,
                "X-DEVICE-ID": Device.default.deviceGUID.uuidString,
                "X-FB": "1"
            ])
            .prepare { request, response in
                guard let response = response else { return request }
                guard let nextMaxId = try? response.get().nextMaxId.string() else { return nil }
                // Update current `body`.
                return try? request.appending(body: ["reason": "pagination", "max_id": nextMaxId])
            }
            .locking(Secret.self) {
                return $0
                    .appending(header: $1.header)
                    .replacing(body: [
                        "is_prefetch": "0",
                        "feed_view_info": "",
                        "seen_posts": "",
                        "phone_id": Device.default.phoneGUID.uuidString,
                        "is_pull_to_refresh": "0",
                        "battery_level": "72",
                        "timezone_offset": "43200",
                        "device_id": Device.default.deviceGUID.uuidString,
                        "_uuid": Device.default.deviceGUID.uuidString,
                        "is_charging": "0",
                        "will_sound_on": "1",
                        "is_on_screen": "true",
                        "is_async_ads_in_headload_enabled": "false",
                        "is_async_ads_double_request": "false",
                        "is_async_ads_rti": "false",
                        "latest_story_pk": "",
                        "reason": "cold_start_fresh",
                        "_csrftoken": $1.crossSiteRequestForgery.value,
                        "client_session_id": $1.session.value
                    ])
            }

        /// All posts for user matching `identifier`.
        /// - parameter identifier: A `String` holding reference to a valid user identifier.
        public static func posts(by identifier: String) -> ResponsePaginated {
            return base.user.appending(path: identifier).paginating().locking(Secret.self)
        }

        /// All available stories for user matching `identifier`.
        /// - parameter identifier: A `String` holding reference to a valid user identifier.
        public static func stories(by identifier: String) -> ResponsePaginated {
            return base.user.appending(path: identifier).reel_media.paginating().locking(Secret.self)
        }

        /// All available stories for user matching `identifiers`.
        /// - parameter identifiers: A `Collection` of `String`s holding reference to valud user identifiers.
        public static func stories<C: Collection>(by identifiers: C) -> ResponseDisposable where C.Element == String {
            return Endpoint.version1.feed.reels_media
                .appendingDefaultHeader()
                .prepare()
                .locking(Secret.self) {
                    $0.appending(header: $1.header)
                        .signing(body: ["_csrftoken": $1.crossSiteRequestForgery.value,
                                        "user_ids": Array(identifiers),
                                        "_uid": $1.identifier ?? "",
                                        "_uuid": Device.default.deviceGUID.uuidString,
                                        "supported_capabilities_new": SupportedCapabilities.default.map { ["name": $0.key, "value": $0.value] },
                                        "source": "feed_timeline"])
                }
        }

        /// All posts a user matching `identifier` is tagged in.
        /// - parameter identifier: A `String` holding reference to a valid user identifier.
        public static func posts(including identifier: String) -> ResponsePaginated {
            return Endpoint.version1.usertags
                .appending(path: identifier)
                .feed
                .appendingDefaultHeader()
                .paginating()
                .locking(Secret.self)
        }

        /// All media matching `tag`.
        /// - parameter tag: A `String` holding reference to a valid _#tag_.
        public static func tagged(with tag: String) -> ResponsePaginated {
            return base.tag.appending(path: tag).paginating().locking(Secret.self)
        }
    }
}
