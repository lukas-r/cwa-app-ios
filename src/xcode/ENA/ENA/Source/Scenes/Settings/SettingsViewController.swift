//
//  SettingsViewController.swift
//  ENA
//
//  Created by Tikhonov, Aleksandr on 28.04.20.
//  Copyright © 2020 SAP SE. All rights reserved.
//

import ExposureNotification
import UIKit
import MessageUI

final class SettingsViewController: UIViewController {
    // MARK: Properties
    @IBOutlet weak var trackingStatusLabel: UILabel!
    @IBOutlet weak var sendLogFileView: UIView!
    @IBOutlet weak var tracingStackView: UIStackView!
    @IBOutlet weak var tracingContainerView: UIView!
    @IBOutlet weak var tracingButton: UIButton!
    @IBOutlet weak var notificationStatusLabel: UILabel!
    @IBOutlet weak var notificationsContainerView: UIView!
    @IBOutlet weak var notificationStackView: UIStackView!
    @IBOutlet weak var mobileDataSwitch: ENASwitch!

    let manager: ExposureManager
    init?(coder: NSCoder, manager: ExposureManager) {
        self.manager = manager
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        checkTracingStatus()
    }

    // MARK: Actions
    @IBAction func mobileDataValueChanged(_ sender: Any) {
        if mobileDataSwitch.isOn {

        } else {
            
        }
    }

    @IBAction func showNotificationSettings(_: Any) {
        guard
            let settingsURL = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(settingsURL) else {
                return
        }
        UIApplication.shared.open(settingsURL)
    }

    @IBAction func showTracingDetails(_: Any) {
        let storyboard = AppStoryboard.exposureNotificationSetting.instance
        let vc = storyboard.instantiateViewController(identifier: "ExposureNotificationSettingViewController", creator: { coder in
            ExposureNotificationSettingViewController(coder: coder, manager: self.manager)
        }
        )
        self.present(vc, animated: true, completion: nil)
    }


    @IBAction func sendLogFile(_: Any) {
        let alert = UIAlertController(title: "Send Log", message: "", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Please enter email"
        }

        let action = UIAlertAction(title: "Send Log File", style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }

            guard let emailText = alert.textFields?[0].text else {
                return
            }

            if !MFMailComposeViewController.canSendMail() {
                return
            }

            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = strongSelf
            composeVC.setToRecipients([emailText])
            composeVC.setSubject("Log File")

            guard let logFile = appLogger.getLoggedData() else {
                return
            }
            composeVC.addAttachmentData(logFile, mimeType: "txt", fileName: "Log")

            self?.present(composeVC, animated: true, completion: nil)
        }

        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    @objc
    private func willEnterForeground() {
        notificationSettings()
        checkTracingStatus()
    }

    // MARK: View Helper
    private func setupView() {
        #if !APP_STORE
            sendLogFileView.isHidden = false
        #endif
        // receive status of manager
        checkTracingStatus()
        notificationSettings()

        tracingStackView.isUserInteractionEnabled = false
        notificationStackView.isUserInteractionEnabled = false
        tracingContainerView.setBorder(
            at: [.top, .bottom],
            with: UIColor.preferredColor(for: ColorStyle.separator),
            thickness: 1
        )
        notificationsContainerView.setBorder(at: [.top, .bottom], with: UIColor.preferredColor(for: ColorStyle.separator), thickness: 1)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared
        )
    }

    private func notificationSettings() {
        let currentCenter = UNUserNotificationCenter.current()

        currentCenter.getNotificationSettings { settings in
            self.setNotificationStatus(for: settings.authorizationStatus)
        }
    }

    private func checkTracingStatus() {
        manager.preconditions().contains(.enabled) ?
            setTrackingStatusActive(to: true) :
            setTrackingStatusActive(to: false)
    }

    private func setTrackingStatusActive(to active: Bool) {
        DispatchQueue.main.async {
            if active {
                self.trackingStatusLabel.text = AppStrings.Settings.trackingStatusActive
            } else {
                self.trackingStatusLabel.text = AppStrings.Settings.trackingStatusInactive
            }
        }
    }

    private func setNotificationStatus(for status: UNAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.notificationStatusLabel.text = AppStrings.Settings.notificationStatusActive
            case .notDetermined:
                let currentCenter = UNUserNotificationCenter.current()
                currentCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                    DispatchQueue.main.async {
                        if error != nil {
                            // Handle the error here.
                            self.notificationStatusLabel.text = AppStrings.Settings.notificationStatusInactive
                            return
                        }
                        self.notificationStatusLabel.text = AppStrings.Settings.notificationStatusActive
                        // Enable or disable features based on the authorization.
                    }
                }
            default:
                self.notificationStatusLabel.text = AppStrings.Settings.notificationStatusInactive
            }
        }
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
