//
//  InteractionPresenter.swift
//  ApptentiveKit
//
//  Created by Frank Schmitt on 7/21/20.
//  Copyright © 2020 Apptentive, Inc. All rights reserved.
//

import UIKit

/// An `InteractionPresenter` is used by the Apptentive SDK to present UI represented by `Interaction`  objects to the user.
open class InteractionPresenter {
    /// A view controller that can be used to present view-controller-based interactions.
    weak var presentingViewController: UIViewController?
    weak var presentedViewController: UIViewController?

    var presentedInteraction: Interaction?

    var delegate: InteractionDelegate?

    /// Creates a new default interaction presenter.
    public init() {}

    /// Presents an interaction.
    /// - Parameters:
    ///   - interaction: The interaction to present.
    ///   - presentingViewController: The view controller to use to present the interaction.
    /// - Throws: If the `sender` property isn't set, if the interaction isn't recognized, or if the presenting view controller is missing or invalid.
    func presentInteraction(_ interaction: Interaction, from presentingViewController: UIViewController? = nil) throws {
        guard let delegate = self.delegate else {
            throw ApptentiveError.internalInconsistency
        }

        if let presentingViewController = presentingViewController {
            self.presentingViewController = presentingViewController
        }

        switch interaction.configuration {
        case .appleRatingDialog:
            AppleRatingDialogController(interaction: interaction, delegate: delegate).requestReview()

        case .enjoymentDialog(let configuration):
            let viewModel = EnjoymentDialogViewModel(configuration: configuration, interaction: interaction, interactionDelegate: delegate)
            try self.presentEnjoymentDialog(with: viewModel)

        case .navigateToLink(let configuration):
            let controller = NavigateToLinkController(configuration: configuration, interaction: interaction, interactionDelegate: delegate)
            controller.navigateToLink()

        case .survey(let configuration):
            let viewModel = SurveyViewModel(configuration: configuration, interaction: interaction, interactionDelegate: delegate)
            try self.presentSurvey(with: viewModel)

        case .textModal(let configuration):
            let viewModel = TextModalViewModel(configuration: configuration, interaction: interaction, interactionDelegate: delegate)
            try self.presentTextModal(with: viewModel)

        case .messageCenter(let configuration):
            let viewModel = MessageCenterViewModel(configuration: configuration, interaction: interaction, interactionDelegate: delegate)
            try self.presentMessageCenter(with: viewModel)

        case .notImplemented:
            let viewModel = NotImplementedAlertViewModel(interactionTypeName: interaction.typeName)
            try self.presentViewController(UIAlertController(viewModel: viewModel))
            throw InteractionPresenterError.notImplemented(interaction.typeName, interaction.id)

        case .failedDecoding:
            throw InteractionPresenterError.decodingFailed(interaction.typeName, interaction.id)
        }

        self.presentedInteraction = interaction
    }

    /// Presents an EnjoymentDialog ("Love Dialog") interaction.
    ///
    /// Override this method to change the way that love dialogs are presented, such as to use a custom view controller.
    /// - Parameter viewModel: the love dialog view model that represents the love dialog and handles button taps.
    /// - Throws: Default behavior is to rethrow errors encountered when calling `present(_:)`.
    open func presentEnjoymentDialog(with viewModel: EnjoymentDialogViewModel) throws {
        let viewController = UIAlertController(viewModel: viewModel)

        try self.presentViewController(
            viewController,
            completion: {
                viewModel.launch()
            })
    }

    /// Presents a Message Center Interaction.
    ///
    /// Override this method to change the way Message Center is presented, such as to use a custom view controller.
    /// - Parameter viewModel: the message center view model that represents the message center and handles sending and receiving messages.
    /// - Throws: Default behavior is to rethrow errors encountered when calling `present(_:)`.
    open func presentMessageCenter(with viewModel: MessageCenterViewModel) throws {

        let messageViewController = MessageCenterViewController(viewModel: viewModel)

        let navController = ApptentiveNavigationController(rootViewController: messageViewController)

        try self.presentViewController(
            navController,
            completion: {
                viewModel.launch()
            })
    }

    /// Presents a Survey interaction.
    ///
    /// Override this method to change the way Surveys are presented, such as to use a custom view controller.
    /// - Parameter viewModel: the survey view model that represents the survey and handles submissions.
    /// - Throws: Default behavior is to rethrow errors encountered when calling `present(_:)`.
    open func presentSurvey(with viewModel: SurveyViewModel) throws {
        let viewController = viewModel.presentationStyle == .card ? CardViewController(viewModel: viewModel) : SurveyViewController(viewModel: viewModel)

        let navigationController = ApptentiveNavigationController(rootViewController: viewController)

        try self.presentViewController(
            navigationController,
            completion: {
                viewModel.launch()
            })
    }

    /// Presents a TextModal ("Note") interaction.
    ///
    /// Override this method to change the way that notes are presented, such as to use a custom view controller.
    /// - Parameter viewModel: the love dialog view model that represents the love dialog and handles button taps.
    /// - Throws: Default behavior is to rethrow errors encountered when calling `present(_:)`.
    open func presentTextModal(with viewModel: TextModalViewModel) throws {
        let viewController = UIAlertController(viewModel: viewModel)

        try self.presentViewController(
            viewController,
            completion: {
                viewModel.launch()
            })
    }

    /// Presents a view-controller-based interaction.
    ///
    /// Override this method to change the way interactions are presented.
    ///
    /// - Parameters:
    ///  - viewControllerToPresent: the interaction view controller that should be presented.
    ///  - completion: a closure that is called when the interaction presentation completes.
    /// - Throws: if the `presentingViewController` property is nil or has an unrecoverable issue.
    open func presentViewController(_ viewControllerToPresent: UIViewController, completion: (() -> Void)? = {}) throws {
        guard let presentingViewController = self.validatedPresentingViewController else {
            throw InteractionPresenterError.noPresentingViewController
        }

        // Workaround for iOS 15 beta 8 clear bars at scroll view extrema.
        if let navigationController = viewControllerToPresent as? ApptentiveNavigationController, let backgroundColor = ApptentiveNavigationController.barTintColor {
            navigationController.view.backgroundColor = backgroundColor
        }

        viewControllerToPresent.modalPresentationStyle = .apptentive

        presentingViewController.present(viewControllerToPresent, animated: true, completion: completion)

        self.presentedViewController = viewControllerToPresent
    }

    /// Checks the `presentingViewController` property and recovers from common failure modes.
    public var validatedPresentingViewController: UIViewController? {
        // Fall back to the crawling the window's VC hierachy if certain failures exist.
        // TODO: make sure this works with scene-based apps.
        if self.presentingViewController == nil || self.presentingViewController?.isViewLoaded == false || self.presentingViewController?.view.window == nil {
            self.presentingViewController = UIApplication.shared.keyWindow?.topViewController
        }

        // If we have a presenting view but one of its ancestors' `isBeingDismissed` is set, use that VC's parent.
        if let presentingViewController = self.presentingViewController,
            let dismissingAncestor = Self.findDismissingAncestor(of: presentingViewController),
            let parentOfDismissingAncestor = Self.findParentViewController(of: dismissingAncestor)
        {
            return parentOfDismissingAncestor
        } else {
            // Otherwise, as far as we know, the presenting view controller is good.
            return presentingViewController
        }
    }

    open func dismissPresentedViewController(animated: Bool) {
        self.presentedViewController?.dismiss(animated: animated)

        var dismissEvent = Event.cancel(from: self.presentedInteraction)
        dismissEvent.userInfo = .dismissCause(.init(cause: "notification"))

        self.delegate?.engage(event: dismissEvent)
    }

    /// Walks up the view controller hierarchy to find any ancestors that are being dismissed, and returns that ancestor's parent, or nil if no parents are being dismissed.
    /// - Parameter viewController: The view controller whose parents should be checked for "is being dismissed" status.
    /// - Returns: The parent of the view controller that is being dismissed, if one exists that is an ancestor of `viewController`.
    private static func findDismissingAncestor(of viewController: UIViewController) -> UIViewController? {
        if viewController.isBeingDismissed {
            return viewController
        } else if let parent = Self.findParentViewController(of: viewController) {
            return findDismissingAncestor(of: parent)
        } else {
            return nil
        }
    }

    /// Finds the next UIViewController subclass in the responder chain starting with the specified responder.
    /// - Parameter responder: The responder at which to start searching.
    /// - Returns: The next UIViewController subclass in the responder chain, if one exists.
    private static func findParentViewController(of responder: UIResponder) -> UIViewController? {
        guard let next = responder.next else {
            return nil  // Responder chain is broken, or we've reached the end.
        }

        if let viewController = next as? UIViewController {
            return viewController
        } else {
            return findParentViewController(of: next)
        }
    }
}

/// An error that occurs while presenting an interaction.
public enum InteractionPresenterError: Error {
    case notImplemented(String, String)
    case decodingFailed(String, String)
    case noPresentingViewController
}

struct CancelInteractionCause: Codable, Equatable {
    let cause: String
}
