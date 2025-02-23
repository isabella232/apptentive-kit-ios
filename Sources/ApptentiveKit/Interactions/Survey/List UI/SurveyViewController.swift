//
//  SurveyViewController.swift
//  ApptentiveKit
//
//  Created by Frank Schmitt on 7/22/20.
//  Copyright © 2020 Apptentive, Inc. All rights reserved.
//

import UIKit

class SurveyViewController: UITableViewController, UITextFieldDelegate, UITextViewDelegate, SurveyViewModelDelegate, UIAdaptivePresentationControllerDelegate {
    static let animationDuration = 0.30

    let viewModel: SurveyViewModel
    let introductionView: SurveyIntroductionView
    let submitView: SurveySubmitView

    var firstResponderIndexPath: IndexPath? {
        didSet {
            if let indexPath = self.firstResponderIndexPath {
                self.firstResponderCell = self.tableView.cellForRow(at: indexPath)
            } else {
                self.firstResponderCell = nil
            }
        }
    }
    var firstResponderCell: UITableViewCell?

    enum FooterMode {
        case submitButton
        case thankYou
        case validationError
    }

    var footerMode: FooterMode = .submitButton {
        didSet {
            var viewToHide: UIView?
            var viewToShow: UIView?

            switch self.footerMode {
            case .submitButton:
                viewToShow = self.submitView.submitButton
                viewToHide = self.submitView.submitLabel

            case .thankYou:
                self.submitView.submitLabel.text = self.viewModel.thankYouMessage
                self.submitView.submitLabel.textColor = .apptentiveSubmitLabel
                viewToShow = self.submitView.submitLabel

            case .validationError:

                self.submitView.submitLabel.text = self.viewModel.validationErrorMessage
                self.submitView.submitLabel.textColor = .apptentiveError
                viewToShow = self.submitView.submitLabel
            }

            UIView.transition(
                with: self.submitView, duration: 0.33, options: .transitionCrossDissolve
            ) {
                viewToHide?.isHidden = true
                viewToShow?.isHidden = false
            }
        }
    }

    init(viewModel: SurveyViewModel) {
        self.viewModel = viewModel
        self.introductionView = SurveyIntroductionView(frame: .zero)
        self.submitView = SurveySubmitView(frame: .zero)
        super.init(style: .apptentive)

        viewModel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .apptentiveGroupedBackground
        self.tableView.separatorColor = .apptentiveSeparator

        self.configureTermsOfService()
        self.navigationController?.presentationController?.delegate = self

        if let headerLogo = UIImage.apptentiveHeaderLogo {
            let headerImageView = UIImageView(image: headerLogo.withRenderingMode(.alwaysOriginal))
            self.navigationItem.titleView = headerImageView
        } else {
            self.navigationItem.title = self.viewModel.name
        }

        self.introductionView.textLabel.text = self.viewModel.introduction

        self.submitView.submitButton.setTitle(self.viewModel.submitButtonText, for: .normal)
        self.submitView.submitButton.addTarget(self, action: #selector(submitSurvey), for: .touchUpInside)

        self.navigationItem.rightBarButtonItem = .apptentiveClose
        self.navigationItem.rightBarButtonItem?.target = self
        self.navigationItem.rightBarButtonItem?.action = #selector(closeSurvey)

        self.tableView.allowsMultipleSelection = true
        self.tableView.keyboardDismissMode = .interactive

        self.tableView.tableHeaderView = self.introductionView
        self.tableView.tableFooterView = self.submitView

        self.tableView.register(SurveyMultiLineCell.self, forCellReuseIdentifier: "multiLine")
        self.tableView.register(SurveySingleLineCell.self, forCellReuseIdentifier: "singleLine")
        self.tableView.register(SurveyChoiceCell.self, forCellReuseIdentifier: "choice")
        self.tableView.register(SurveyOtherChoiceCell.self, forCellReuseIdentifier: "otherCollapsed")
        self.tableView.register(SurveyOtherChoiceCell.self, forCellReuseIdentifier: "otherExpanded")
        self.tableView.register(SurveyRangeCell.self, forCellReuseIdentifier: "rangeControl")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "unimplemented")

        self.tableView.register(SurveyQuestionHeaderView.self, forHeaderFooterViewReuseIdentifier: "question")

        self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedSectionHeaderHeight = 66.0
        self.tableView.estimatedRowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateHeaderFooterSize()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        self.updateHeaderFooterSize()
        self.tableView.tableHeaderView = self.introductionView
        self.tableView.tableFooterView = self.submitView
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.viewModel.questions.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.viewModel.questions[section] {
        case is SurveyViewModel.FreeformQuestion:
            return 1
        case let choiceQuestion as SurveyViewModel.ChoiceQuestion:
            return choiceQuestion.choices.count

        case is SurveyViewModel.RangeQuestion:
            return 1

        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let question = self.viewModel.questions[indexPath.section]

        var reuseIdentifier: String

        switch question {
        case let freeformQuestion as SurveyViewModel.FreeformQuestion:
            reuseIdentifier = freeformQuestion.allowMultipleLines ? "multiLine" : "singleLine"

        case let choiceQuestion as SurveyViewModel.ChoiceQuestion:
            let choice = choiceQuestion.choices[indexPath.row]
            if choice.supportsOther && choice.isSelected == false {
                reuseIdentifier = "otherCollapsed"
            } else if choice.supportsOther && choice.isSelected == true {
                reuseIdentifier = "otherExpanded"
            } else {
                reuseIdentifier = "choice"
            }

        case is SurveyViewModel.RangeQuestion:
            reuseIdentifier = "rangeControl"

        default:
            reuseIdentifier = "unimplemented"
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.selectionStyle = .none

        switch (question, cell) {
        case (let freeformQuestion as SurveyViewModel.FreeformQuestion, let singleLineCell as SurveySingleLineCell):
            singleLineCell.textField.placeholder = freeformQuestion.placeholderText
            singleLineCell.textField.text = freeformQuestion.value
            singleLineCell.textField.delegate = self
            singleLineCell.textField.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
            singleLineCell.textField.tag = self.tag(for: indexPath)
            singleLineCell.textField.accessibilityIdentifier = String(indexPath.section)
            singleLineCell.tableViewStyle = tableView.style
            singleLineCell.isMarkedAsInvalid = question.isMarkedAsInvalid

        case (let freeformQuestion as SurveyViewModel.FreeformQuestion, let multiLineCell as SurveyMultiLineCell):
            multiLineCell.textView.text = freeformQuestion.value
            multiLineCell.placeholderLabel.text = freeformQuestion.placeholderText
            multiLineCell.placeholderLabel.isHidden = !(freeformQuestion.value?.isEmpty ?? true)
            multiLineCell.textView.delegate = self
            multiLineCell.textView.tag = self.tag(for: indexPath)
            multiLineCell.textView.accessibilityIdentifier = String(indexPath.section)
            multiLineCell.textView.accessibilityLabel = freeformQuestion.placeholderText
            multiLineCell.tableViewStyle = tableView.style
            multiLineCell.isMarkedAsInvalid = question.isMarkedAsInvalid

        case (let rangeQuestion as SurveyViewModel.RangeQuestion, let rangeChoiceCell as SurveyRangeCell):
            rangeChoiceCell.choiceLabels = rangeQuestion.choiceLabels

            guard let segmentedControl = rangeChoiceCell.segmentedControl else {
                assertionFailure("Expected range cell to have segmented control.")
                break
            }

            segmentedControl.addTarget(self, action: #selector(rangeControlValueDidChange(_:)), for: .valueChanged)
            segmentedControl.tag = self.tag(for: indexPath)
            for (index, subview) in segmentedControl.subviews.enumerated() {
                let segmentLabel = segmentedControl.titleForSegment(at: index)
                subview.accessibilityLabel = segmentLabel
                subview.accessibilityHint = rangeQuestion.accessibilityHintForSegment
                subview.accessibilityTraits = .none
            }

            if let selectedIndex = rangeQuestion.selectedValueIndex {
                segmentedControl.selectedSegmentIndex = selectedIndex
            } else {
                segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
            }
            rangeChoiceCell.minLabel.text = rangeQuestion.minText
            rangeChoiceCell.maxLabel.text = rangeQuestion.maxText

        case (let choiceQuestion as SurveyViewModel.ChoiceQuestion, let choiceCell as SurveyChoiceCell):
            choiceCell.textLabel?.text = choiceQuestion.choices[indexPath.row].label
            choiceCell.detailTextLabel?.text = nil
            choiceCell.accessibilityLabel = choiceQuestion.choices[indexPath.row].label
            switch choiceQuestion.selectionStyle {
            case .radioButton:
                choiceCell.imageView?.image = .apptentiveRadioButton
                choiceCell.imageView?.highlightedImage = .apptentiveRadioButtonSelected
            case .checkbox:
                choiceCell.imageView?.image = .apptentiveCheckbox
                choiceCell.imageView?.highlightedImage = .apptentiveCheckboxSelected
            }

        case (let choiceQuestion as SurveyViewModel.ChoiceQuestion, let otherCell as SurveyOtherChoiceCell):
            let choice = choiceQuestion.choices[indexPath.row]

            otherCell.otherTextLabel.text = choice.label
            otherCell.isSelected = choice.isSelected
            otherCell.textField.text = choice.value
            otherCell.textField.delegate = self
            otherCell.textField.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
            otherCell.textField.tag = self.tag(for: indexPath)
            otherCell.isMarkedAsInvalid = choice.isMarkedAsInvalid
            switch choiceQuestion.selectionStyle {
            case .radioButton:
                otherCell.imageView?.image = .apptentiveRadioButton
                otherCell.imageView?.highlightedImage = .apptentiveRadioButtonSelected
            case .checkbox:
                otherCell.imageView?.image = .apptentiveCheckbox
                otherCell.imageView?.highlightedImage = .apptentiveCheckboxSelected
            }

        default:
            cell.textLabel?.text = "Unimplemented"
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let question = self.viewModel.questions[section]

        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "question") as? SurveyQuestionHeaderView else {
            assertionFailure("Unexpected header view registered for identifier `question`.")
            return nil
        }

        let instructionsText = [question.requiredText, question.instructions].compactMap({ $0 }).joined(separator: " — ")

        header.questionLabel.text = question.text
        header.instructionsLabel.text = instructionsText
        header.instructionsLabel.isHidden = instructionsText.isEmpty
        header.questionLabel.textColor = question.isMarkedAsInvalid ? .apptentiveError : .apptentiveQuestionLabel
        header.instructionsLabel.textColor = question.isMarkedAsInvalid ? .apptentiveError : .apptentiveSecondaryLabel
        header.contentView.accessibilityLabel = question.accessibilityLabel
        header.contentView.accessibilityHint = question.accessibilityHint
        return header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let question = self.viewModel.questions[section]
        return question.isMarkedAsInvalid ? question.errorMessage : nil
    }

    // MARK: Table View Delegate

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let choiceQuestion = self.viewModel.questions[indexPath.section] as? SurveyViewModel.ChoiceQuestion else {
            return  // Not a choice question
        }

        cell.isSelected = choiceQuestion.choices[indexPath.row].isSelected
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let choiceQuestion = self.viewModel.questions[indexPath.section] as? SurveyViewModel.ChoiceQuestion else {
            return  // Not a choice question
        }

        choiceQuestion.toggleChoice(at: indexPath.row)

        // Automatically focus text field in "Other" choice cells.
        if choiceQuestion.choices[indexPath.row].supportsOther {
            guard let otherCell = tableView.cellForRow(at: indexPath) as? SurveyOtherChoiceCell else {
                return assertionFailure("Expected other cell for other choice")
            }
            otherCell.textField.becomeFirstResponder()
            let choice = choiceQuestion.choices[indexPath.row]
            choice.isSelected = true
            otherCell.isSelected = true

            otherCell.setExpandedConstraints()
            UIView.animate(withDuration: SurveyViewController.animationDuration) {
                otherCell.textField.alpha = 1
                otherCell.layoutIfNeeded()
            }

            self.tableView.beginUpdates()
            self.tableView.endUpdates()

        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let choiceQuestion = self.viewModel.questions[indexPath.section] as? SurveyViewModel.ChoiceQuestion else {
            return  // Not a choice question
        }

        choiceQuestion.toggleChoice(at: indexPath.row)
        let choice = choiceQuestion.choices[indexPath.row]

        // Override deselection of a radio button

        if choice.isSelected {
            self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        } else if choice.supportsOther {
            // Automatically unfocus text field in "Other" choice cells (assuming not a radio button).
            guard let otherCell = tableView.cellForRow(at: indexPath) as? SurveyOtherChoiceCell else {
                return assertionFailure("Expected other cell for other choice")
            }

            otherCell.textField.resignFirstResponder()
            choice.isSelected = false
            otherCell.isSelected = false
            otherCell.setCollapsedConstraints()
            UIView.animate(withDuration: SurveyViewController.animationDuration) {
                otherCell.textField.alpha = 0
                otherCell.layoutIfNeeded()
            }
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footerView = view as? UITableViewHeaderFooterView else {
            return
        }

        footerView.textLabel?.alpha = 1  // We may have faded this out in `surveyViewModelValidationDidChange(_:)`.
        footerView.textLabel?.textColor = .apptentiveError  // Footers always display an error in the error color.
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let firstIndex = self.viewModel.invalidQuestionIndexes.min() {
            if let header = self.tableView.headerView(forSection: firstIndex) as? SurveyQuestionHeaderView {
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: header)
            }
        }
    }

    // MARK: - Survey View Model delgate

    func surveyViewModelDidSubmit(_ viewModel: SurveyViewModel) {
        if let _ = self.viewModel.thankYouMessage {
            self.footerMode = .thankYou

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                self.dismiss()
            }
        } else {
            self.dismiss()
        }
    }

    func surveyViewModelValidationDidChange(_ viewModel: SurveyViewModel) {
        self.footerMode = viewModel.isMarkedAsInvalid ? .validationError : .submitButton

        self.tableView.beginUpdates()  // Animate in/out any error message footers

        var visibleSectionIndexes = tableView.indexPathsForVisibleRows?.map { $0.section } ?? []

        // There might be a header view for a subsequent section whose top row isn't visible.
        if let lastVisibleSectionIndex = visibleSectionIndexes.last, lastVisibleSectionIndex < self.tableView.numberOfSections - 1 {
            visibleSectionIndexes.append(lastVisibleSectionIndex + 1)
        }

        // There might be a footer view for a previous section whose bottom row isn't visible.
        if let firstVisibleSectionIndex = visibleSectionIndexes.first, firstVisibleSectionIndex >= 1 {
            visibleSectionIndexes.append(firstVisibleSectionIndex - 1)
        }

        visibleSectionIndexes.forEach({ sectionIndex in
            let question = viewModel.questions[sectionIndex]

            if let header = self.tableView.headerView(forSection: sectionIndex) as? SurveyQuestionHeaderView {
                UIView.transition(
                    with: header, duration: Self.animationDuration, options: .transitionCrossDissolve
                ) {
                    header.questionLabel.textColor = question.isMarkedAsInvalid ? .apptentiveError : .apptentiveQuestionLabel
                    header.instructionsLabel.textColor = question.isMarkedAsInvalid ? .apptentiveError : .apptentiveSecondaryLabel
                }
                header.contentView.accessibilityLabel = question.accessibilityLabel
                header.contentView.accessibilityHint = question.accessibilityHint

            }

            // The footer's position animates properly when a question is un-marked,
            // but the text stays visible for some reason (a UIKit bug?).
            if let footer = self.tableView.footerView(forSection: sectionIndex) {
                UIView.animate(withDuration: Self.animationDuration) {
                    footer.textLabel?.alpha = question.isMarkedAsInvalid ? 1 : 0
                }
            }
        })

        self.tableView.indexPathsForVisibleRows?.forEach { indexPath in
            guard let cell = self.tableView.cellForRow(at: indexPath) else {
                return  // Cell may already be offscreen
            }

            let question = self.viewModel.questions[indexPath.section]
            if let choiceQuestion = question as? SurveyViewModel.ChoiceQuestion, let choiceCell = cell as? SurveyOtherChoiceCell {
                choiceCell.isMarkedAsInvalid = choiceQuestion.choices[indexPath.row].isMarkedAsInvalid
            } else if let freeformQuestion = question as? SurveyViewModel.FreeformQuestion {
                if let singleLineCell = cell as? SurveySingleLineCell {
                    singleLineCell.isMarkedAsInvalid = freeformQuestion.isMarkedAsInvalid
                } else if let multiLineCell = cell as? SurveyMultiLineCell {
                    multiLineCell.isMarkedAsInvalid = freeformQuestion.isMarkedAsInvalid
                }
            }
        }

        if let firstResponderIndexPath = self.firstResponderIndexPath, let firstResponderCell = self.firstResponderCell {
            if let otherChoiceCell = firstResponderCell as? SurveyOtherChoiceCell,
                let choiceQuestion = self.viewModel.questions[firstResponderIndexPath.section] as? SurveyViewModel.ChoiceQuestion
            {
                otherChoiceCell.isMarkedAsInvalid = choiceQuestion.choices[firstResponderIndexPath.row].isMarkedAsInvalid
            }
        }

        self.tableView.endUpdates()
    }

    private func setIsMarkedAsInvalid(at indexPath: IndexPath, cell: UITableViewCell?) {
        let question = self.viewModel.questions[indexPath.section]

        switch (question, cell) {
        case (let choiceQuestion as SurveyViewModel.ChoiceQuestion, let otherCell as SurveyOtherChoiceCell):
            otherCell.isMarkedAsInvalid = choiceQuestion.choices[indexPath.row].isMarkedAsInvalid

        case (let freeformQuestion as SurveyViewModel.FreeformQuestion, let singleLineCell as SurveySingleLineCell):
            singleLineCell.isMarkedAsInvalid = freeformQuestion.isMarkedAsInvalid

        case (let freeformQuestion as SurveyViewModel.FreeformQuestion, let multiLineCell as SurveyMultiLineCell):
            multiLineCell.isMarkedAsInvalid = freeformQuestion.isMarkedAsInvalid

        default:
            break
        }
    }

    func surveyViewModelSelectionDidChange(_ viewModel: SurveyViewModel) {

        self.tableView.indexPathsForVisibleRows?.forEach { indexPath in
            guard let choiceQuestion = self.viewModel.questions[indexPath.section] as? SurveyViewModel.ChoiceQuestion else {
                return  // Not a choice question
            }

            guard let cell = self.tableView.cellForRow(at: indexPath) else {
                return  // Cell may already be offscreen
            }

            let isSelected = choiceQuestion.choices[indexPath.row].isSelected

            if let choiceCell = cell as? SurveyChoiceCell {
                choiceCell.isSelected = isSelected
            } else if let choiceCell = cell as? SurveyOtherChoiceCell {

                // cell selection is out of sync with view model selection
                if (!isSelected && choiceCell.isSelected) || (isSelected && !choiceCell.isSelected) {
                    choiceCell.isSelected = isSelected
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }

            } else {
                return assertionFailure("Should have choice cell for choice question")
            }
        }
    }

    // MARK: - Targets

    @objc func closeSurvey() {
        if self.viewModel.hasAnswer {
            self.confirmCancel()
        } else {
            self.cancel()
        }
    }

    @objc func openTermsAndConditions() {
        self.viewModel.openTermsAndConditions()
    }

    @objc func submitSurvey() {
        self.viewModel.submit()

        if !self.viewModel.isValid {
            self.scrollToFirstInvalidQuestion()
        }
    }

    @objc func textFieldChanged(_ textField: UITextField) {
        let indexPath = self.indexPath(forTag: textField.tag)
        let question = self.viewModel.questions[indexPath.section]

        if let freeformQuestion = question as? SurveyViewModel.FreeformQuestion {
            freeformQuestion.value = textField.text
        } else if let choiceQuestion = question as? SurveyViewModel.ChoiceQuestion {
            choiceQuestion.choices[indexPath.row].value = textField.text
        } else {
            return assertionFailure("Text field sending events to wrong question")
        }

    }

    @objc func rangeControlValueDidChange(_ segmentedControl: UISegmentedControl) {
        let indexPath = self.indexPath(forTag: segmentedControl.tag)
        let question = self.viewModel.questions[indexPath.section]
        let rangeQuestion = question as? SurveyViewModel.RangeQuestion
        rangeQuestion?.selectValue(at: segmentedControl.selectedSegmentIndex)
    }

    // MARK: - Text Field Delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    // We probably don't need this now that the Other text field is only visible when the choice is selected.
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let indexPath = self.indexPath(forTag: textField.tag)

        guard let question = self.viewModel.questions[indexPath.section] as? SurveyViewModel.ChoiceQuestion else {
            return  // Not a choice question
        }

        if !question.choices[indexPath.row].isSelected {
            question.toggleChoice(at: indexPath.row)
        }

        self.firstResponderIndexPath = indexPath
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.firstResponderIndexPath = nil
    }

    // MARK: Text View Delegate

    func textViewDidChange(_ textView: UITextView) {
        let indexPath = self.indexPath(forTag: textView.tag)

        guard let question = self.viewModel.questions[indexPath.section] as? SurveyViewModel.FreeformQuestion else {
            return assertionFailure("Text view sending delegate calls to wrong question")
        }

        question.value = textView.text
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        self.firstResponderIndexPath = self.indexPath(forTag: textView.tag)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        self.firstResponderIndexPath = nil
    }

    // MARK: - Adaptive Presentation Controller Delegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.viewModel.cancel()
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        if self.viewModel.hasAnswer {
            DispatchQueue.main.async {
                self.confirmCancel()
            }
            return false
        } else {
            return true
        }
    }

    // MARK: - Private

    private func updateHeaderFooterSize() {
        let introductionSize = self.introductionView.systemLayoutSizeFitting(CGSize(width: self.tableView.bounds.width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)

        self.introductionView.bounds = CGRect(origin: .zero, size: introductionSize)

        let submitSize = self.submitView.systemLayoutSizeFitting(CGSize(width: self.tableView.bounds.width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)

        self.submitView.bounds = CGRect(origin: .zero, size: submitSize)
    }

    private func indexPath(forTag tag: Int) -> IndexPath {
        return IndexPath(row: tag & 0xFFFF, section: tag >> 16)
    }

    private func configureTermsOfService() {
        if let termsLabel = self.viewModel.termsAndConditionsLabel {
            self.navigationController?.setToolbarHidden(false, animated: true)

            let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let barButtonItem = UIBarButtonItem(title: termsLabel, style: .plain, target: self, action: #selector(openTermsAndConditions))

            barButtonItem.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.apptentiveTermsOfServiceLabel, NSAttributedString.Key.foregroundColor: UIColor.apptentiveTermsOfServiceLabel, NSAttributedString.Key.underlineStyle: 1], for: .normal)
            barButtonItem.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.apptentiveTermsOfServiceLabel, NSAttributedString.Key.foregroundColor: UIColor.apptentiveTermsOfServiceLabel, NSAttributedString.Key.underlineStyle: 1], for: .selected)
            self.setToolbarItems([flexible, barButtonItem, flexible], animated: false)
        } else {
            self.navigationController?.setToolbarHidden((UIToolbar.apptentiveMode == .hiddenWhenEmpty), animated: true)
        }
    }

    private func tag(for indexPath: IndexPath) -> Int {
        return (indexPath.section << 16) | (indexPath.item & 0xFFFF)
    }

    private func confirmCancel() {
        let alertController = UIAlertController(title: self.viewModel.closeConfirmationAlertTitle, message: self.viewModel.closeConfirmationAlertMessage, preferredStyle: .actionSheet)
        alertController.addAction(
            UIAlertAction(
                title: self.viewModel.closeConfirmationCloseButtonLabel, style: .destructive,
                handler: { _ in
                    self.cancel(partial: true)

                }))
        alertController.addAction(
            UIAlertAction(
                title: self.viewModel.closeConfirmationBackButtonLabel, style: .cancel,
                handler: { _ in
                    self.viewModel.continuePartial()
                }))

        alertController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem

        self.present(alertController, animated: true, completion: nil)

    }

    private func cancel(partial: Bool = false) {
        self.viewModel.cancel(partial: partial)
        self.dismiss()
    }

    private func dismiss() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    private func scrollToFirstInvalidQuestion() {
        if let firstInvalidQuestionIndex = self.viewModel.invalidQuestionIndexes.first {
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: firstInvalidQuestionIndex), at: .middle, animated: true)
        }
    }
}
