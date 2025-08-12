import UIKit
import LocalAuthentication

protocol AuthenticationViewControllerDelegate: AnyObject {
    func authenticationDidComplete()
    func authenticationDidFail(_ error: Error)
}

class AuthenticationViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: AuthenticationViewControllerDelegate?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let segmentedControl = UISegmentedControl()
    
    // Login form
    private let loginStackView = UIStackView()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let forgotPasswordButton = UIButton(type: .system)
    private let loginButton = UIButton(type: .system)
    private let biometricButton = UIButton(type: .system)
    
    // Signup form
    private let signupStackView = UIStackView()
    private let firstNameTextField = UITextField()
    private let lastNameTextField = UITextField()
    private let signupEmailTextField = UITextField()
    private let signupPasswordTextField = UITextField()
    private let confirmPasswordTextField = UITextField()
    private let signupButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var isLoginMode = true
    private var biometricContext = LAContext()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardHandling()
        checkBiometricAvailability()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Logo and branding
        setupBranding()
        
        // Segmented control
        setupSegmentedControl()
        
        // Forms
        setupLoginForm()
        setupSignupForm()
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        view.addSubview(loadingIndicator)
    }
    
    private func setupBranding() {
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.image = UIImage(systemName: "chart.line.uptrend.xyaxis")
        logoImageView.tintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Ascend"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 32) ?? UIFont.boldSystemFont(ofSize: 32)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "AI-Powered Debt Management"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        subtitleLabel.textAlignment = .center
        
        contentView.addSubview(logoImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.insertSegment(withTitle: "Login", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Sign Up", at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = .white
        segmentedControl.selectedSegmentTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor(named: "AccentLavender") ?? .darkGray
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: .white
        ], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        contentView.addSubview(segmentedControl)
    }
    
    private func setupLoginForm() {
        loginStackView.translatesAutoresizingMaskIntoConstraints = false
        loginStackView.axis = .vertical
        loginStackView.spacing = 16
        loginStackView.distribution = .fill
        
        // Email field
        setupTextField(emailTextField, placeholder: "Email", icon: "envelope")
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        
        // Password field
        setupTextField(passwordTextField, placeholder: "Password", icon: "lock")
        passwordTextField.isSecureTextEntry = true
        
        // Forgot password button
        forgotPasswordButton.setTitle("Forgot Password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        forgotPasswordButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        
        // Login button
        loginButton.setTitle("Login", for: .normal)
        loginButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        loginButton.layer.cornerRadius = 12
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        
        // Biometric button
        biometricButton.setTitle("Login with Face ID", for: .normal)
        biometricButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        biometricButton.setTitleColor(UIColor(named: "AccentLavender") ?? .darkGray, for: .normal)
        biometricButton.backgroundColor = .white
        biometricButton.layer.cornerRadius = 8
        biometricButton.layer.borderWidth = 1
        biometricButton.layer.borderColor = UIColor.systemGray4.cgColor
        biometricButton.addTarget(self, action: #selector(biometricLoginTapped), for: .touchUpInside)
        
        loginStackView.addArrangedSubview(emailTextField)
        loginStackView.addArrangedSubview(passwordTextField)
        loginStackView.addArrangedSubview(forgotPasswordButton)
        loginStackView.addArrangedSubview(loginButton)
        loginStackView.addArrangedSubview(biometricButton)
        
        contentView.addSubview(loginStackView)
    }
    
    private func setupSignupForm() {
        signupStackView.translatesAutoresizingMaskIntoConstraints = false
        signupStackView.axis = .vertical
        signupStackView.spacing = 16
        signupStackView.distribution = .fill
        signupStackView.isHidden = true
        
        // First name field
        setupTextField(firstNameTextField, placeholder: "First Name", icon: "person")
        
        // Last name field
        setupTextField(lastNameTextField, placeholder: "Last Name", icon: "person")
        
        // Email field
        setupTextField(signupEmailTextField, placeholder: "Email", icon: "envelope")
        signupEmailTextField.keyboardType = .emailAddress
        signupEmailTextField.autocapitalizationType = .none
        
        // Password field
        setupTextField(signupPasswordTextField, placeholder: "Password", icon: "lock")
        signupPasswordTextField.isSecureTextEntry = true
        
        // Confirm password field
        setupTextField(confirmPasswordTextField, placeholder: "Confirm Password", icon: "lock")
        confirmPasswordTextField.isSecureTextEntry = true
        
        // Signup button
        signupButton.setTitle("Create Account", for: .normal)
        signupButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        signupButton.setTitleColor(.white, for: .normal)
        signupButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        signupButton.layer.cornerRadius = 12
        signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        
        signupStackView.addArrangedSubview(firstNameTextField)
        signupStackView.addArrangedSubview(lastNameTextField)
        signupStackView.addArrangedSubview(signupEmailTextField)
        signupStackView.addArrangedSubview(signupPasswordTextField)
        signupStackView.addArrangedSubview(confirmPasswordTextField)
        signupStackView.addArrangedSubview(signupButton)
        
        contentView.addSubview(signupStackView)
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, icon: String) {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.leftView = createLeftView(icon: icon)
        textField.leftViewMode = .always
        textField.delegate = self
        textField.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Segmented control
            segmentedControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            // Login form
            loginStackView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 24),
            loginStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loginStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Signup form
            signupStackView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 24),
            signupStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            signupStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            signupStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupKeyboardHandling() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private func createLeftView(icon: String) -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        
        let imageView = UIImageView(frame: CGRect(x: 15, y: 15, width: 20, height: 20))
        imageView.image = UIImage(systemName: icon)
        imageView.tintColor = UIColor(named: "AccentLavender") ?? .darkGray
        imageView.contentMode = .scaleAspectFit
        
        containerView.addSubview(imageView)
        return containerView
    }
    
    private func checkBiometricAvailability() {
        var error: NSError?
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch biometricContext.biometryType {
            case .faceID:
                biometricButton.setTitle("Login with Face ID", for: .normal)
            case .touchID:
                biometricButton.setTitle("Login with Touch ID", for: .normal)
            default:
                biometricButton.isHidden = true
            }
        } else {
            biometricButton.isHidden = true
        }
    }
    
    private func validateLoginForm() -> Bool {
        guard let email = emailTextField.text, !email.isEmpty else {
            showAlert(title: "Error", message: "Please enter your email")
            return false
        }
        
        guard let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter your password")
            return false
        }
        
        return true
    }
    
    private func validateSignupForm() -> Bool {
        guard let firstName = firstNameTextField.text, !firstName.isEmpty else {
            showAlert(title: "Error", message: "Please enter your first name")
            return false
        }
        
        guard let lastName = lastNameTextField.text, !lastName.isEmpty else {
            showAlert(title: "Error", message: "Please enter your last name")
            return false
        }
        
        guard let email = signupEmailTextField.text, !email.isEmpty else {
            showAlert(title: "Error", message: "Please enter your email")
            return false
        }
        
        guard let password = signupPasswordTextField.text, password.count >= 8 else {
            showAlert(title: "Error", message: "Password must be at least 8 characters")
            return false
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, password == confirmPassword else {
            showAlert(title: "Error", message: "Passwords do not match")
            return false
        }
        
        return true
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        isLoginMode = segmentedControl.selectedSegmentIndex == 0
        loginStackView.isHidden = !isLoginMode
        signupStackView.isHidden = isLoginMode
    }
    
    @objc private func loginTapped() {
        guard validateLoginForm() else { return }
        
        loadingIndicator.startAnimating()
        loginButton.isEnabled = false
        
        Task {
            do {
                let user = try await AuthenticationService.shared.login(
                    email: emailTextField.text ?? "",
                    password: passwordTextField.text ?? ""
                )
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.loginButton.isEnabled = true
                    self.delegate?.authenticationDidComplete()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.loginButton.isEnabled = true
                    self.showAlert(title: "Login Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func signupTapped() {
        guard validateSignupForm() else { return }
        
        loadingIndicator.startAnimating()
        signupButton.isEnabled = false
        
        Task {
            do {
                let user = try await AuthenticationService.shared.register(
                    email: signupEmailTextField.text ?? "",
                    password: signupPasswordTextField.text ?? "",
                    firstName: firstNameTextField.text ?? "",
                    lastName: lastNameTextField.text ?? ""
                )
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.signupButton.isEnabled = true
                    self.delegate?.authenticationDidComplete()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.signupButton.isEnabled = true
                    self.showAlert(title: "Signup Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func biometricLoginTapped() {
        biometricContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Login to Ascend") { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Attempt to login with stored credentials
                    self?.performBiometricLogin()
                } else {
                    self?.showAlert(title: "Biometric Login Failed", message: error?.localizedDescription ?? "Please try again")
                }
            }
        }
    }
    
    private func performBiometricLogin() {
        // This would typically retrieve stored credentials from Keychain
        // and attempt login automatically
        loadingIndicator.startAnimating()
        
        Task {
            do {
                // Simulate biometric login
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.delegate?.authenticationDidComplete()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.showAlert(title: "Login Failed", message: "Biometric login failed")
                }
            }
        }
    }
    
    @objc private func forgotPasswordTapped() {
        let alert = UIAlertController(title: "Reset Password", message: "Enter your email to receive a password reset link", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { _ in
            if let email = alert.textFields?.first?.text, !email.isEmpty {
                self.resetPassword(email: email)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func resetPassword(email: String) {
        loadingIndicator.startAnimating()
        
        Task {
            do {
                try await AuthenticationService.shared.resetPassword(email: email)
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.showAlert(title: "Success", message: "Password reset email sent")
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
}

// MARK: - UITextFieldDelegate

extension AuthenticationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if isLoginMode {
            switch textField {
            case emailTextField:
                passwordTextField.becomeFirstResponder()
            case passwordTextField:
                textField.resignFirstResponder()
                loginTapped()
            default:
                textField.resignFirstResponder()
            }
        } else {
            switch textField {
            case firstNameTextField:
                lastNameTextField.becomeFirstResponder()
            case lastNameTextField:
                signupEmailTextField.becomeFirstResponder()
            case signupEmailTextField:
                signupPasswordTextField.becomeFirstResponder()
            case signupPasswordTextField:
                confirmPasswordTextField.becomeFirstResponder()
            case confirmPasswordTextField:
                textField.resignFirstResponder()
                signupTapped()
            default:
                textField.resignFirstResponder()
            }
        }
        return true
    }
}
