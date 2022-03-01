//
//  ResponseSending.swift
//  ApptentiveKit
//
//  Created by Frank Schmitt on 10/6/20.
//  Copyright © 2020 Apptentive, Inc. All rights reserved.
//

import UIKit

typealias InteractionDelegate = ResponseSending & EventEngaging & ReviewRequesting & URLOpening & InvocationInvoking & ResponseRecording & TermsOfServiceProviding & MessageSending & MessageProviding & AttachmentManaging & UnreadMessageUpdating

/// Describes an object that can manage attachments to a draft message and load attachments from an arbitrary message.
protocol AttachmentManaging: AnyObject {
    func addDraftAttachment(data: Data, name: String?, mediaType: String, completion: (Result<URL, Error>) -> Void)
    func addDraftAttachment(url: URL, completion: (Result<URL, Error>) -> Void)
    func removeDraftAttachment(at index: Int, completion: (Result<Void, Error>) -> Void)
    func urlForAttachment(at index: Int, in message: MessageList.Message) -> URL?
    func loadAttachment(at index: Int, in message: MessageList.Message, completion: @escaping (Result<URL, Error>) -> Void)
}

/// Describes an object that can send the unread message ID to the backend to update the unread message count.
protocol UnreadMessageUpdating: AnyObject {
    func markMessageAsRead(_ nonce: String)
}

/// Describes an object that can receive the MessageManager from the backend.
protocol MessageProviding: AnyObject {
    var messageManagerDelegate: MessageManagerDelegate? { get set }
    func getMessages(completion: @escaping ([MessageList.Message]) -> Void)
    func setDraftMessageBody(_ body: String?)
    func getDraftMessage(completion: @escaping (MessageList.Message) -> Void)
}

/// Describes an object that can send messages from the Message Center interaction.
protocol MessageSending: AnyObject {
    /// Sends the draft message.
    /// - Parameter completion: The completion handler to be called with the result of the operation.
    func sendDraftMessage(completion: @escaping (Result<Void, Error>) -> Void)
}

/// Describes an object that can send responses from Survey interactions.
protocol ResponseSending: AnyObject {
    /// Sends the specified survey response to the Apptentive API.
    /// - Parameter surveyResponse: The survey response to send.
    func send(surveyResponse: SurveyResponse)
}

/// Describes an object that can engage an event.
protocol EventEngaging: AnyObject {
    /// Engages the specified event by including the interaction.
    /// - Parameter event: The event to engage.
    func engage(event: Event)
}

/// Describes an object that can process invocations and potentially display interactions.
protocol InvocationInvoking: AnyObject {
    func invoke(_ invocations: [EngagementManifest.Invocation], completion: @escaping (String?) -> Void)
}

/// Describes an object that can request an App Store review.
protocol ReviewRequesting: AnyObject {
    /// Requests an App Store review from the system
    /// - Parameter completion: Called with a value indicating whether the review request was shown.
    func requestReview(completion: @escaping (Bool) -> Void)
}

/// Describes an object that can ask the system to open a URL.
protocol URLOpening: AnyObject {
    /// Asks the system to open the specified URL.
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - completion: Called with a value indicating whether the URL was successfully opened.
    func open(_ url: URL, completion: @escaping (Bool) -> Void)
}

/// Describes an object that can record a response to an interaction.
protocol ResponseRecording: AnyObject {
    /// Records the specified response for later querying in the targeter.
    /// - Parameters:
    ///   - answers: The answers included in the interaction response.
    ///   - questionID: The identifier for the question.
    func recordResponse(_ answers: [Answer], for questionID: String)
}

/// Describes an object representing the terms of service at the bottom of surveys.
protocol TermsOfServiceProviding: AnyObject {
    var termsOfService: TermsOfService? { get set }
}
