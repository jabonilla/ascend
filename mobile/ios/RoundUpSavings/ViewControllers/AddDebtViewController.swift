import UIKit

protocol AddDebtViewControllerDelegate: AnyObject {
    func addDebtViewControllerDidAddDebt(_ debt: Debt)
}

class AddDebtViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: AddDebtViewControllerDelegate?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let nameTextField = UITextField()
    private let typeSegmentedControl = UISegmentedControl()
    private let balanceTextField = UITextField()
    private let originalBalanceTextField = UITextField()
    private let aprTextField = UITextField()
    private let minimumPaymentTextField = UITextField()
    private let dueDatePicker = UIDatePicker()
    private let dueDateLabel = UILabel()
    
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIBarButtonItem()
    
    // MARK: - Data
    
    private var selectedDebtType: Debt.DebtType = .creditCard
    private var selectedDueDate = Date()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        setupKeyboardHandling()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Name field
        setupTextField(nameTextField, placeholder: "Debt Name", icon: "tag")
        
        // Type segmented control
        setupTypeSegmentedControl()
        
        // Balance fields
        setupTextField(balanceTextField, placeholder: "Current Balance", icon: "dollarsign.circle")
        balanceTextField.keyboardType = .decimalPad
        
        setupTextField(originalBalanceTextField, placeholder: "Original Balance", icon: "dollarsign.circle.fill")
        originalBalanceTextField.keyboardType = .decimalPad
        
        // APR field
        setupTextField(aprTextField, placeholder: "Annual Percentage Rate (%)", icon: "percent")
        aprTextField.keyboardType = .decimalPad
        
        // Minimum payment field
        setupTextField(minimumPaymentTextField, placeholder: "Minimum Payment", icon: "creditcard")
        minimumPaymentTextField.keyboardType = .decimalPad
        
        // Due date picker
        setupDueDatePicker()
        
        // Save button
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Add Debt", for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        
        // Add subviews
        contentView.addSubview(nameTextField)
        contentView.addSubview(typeSegmentedControl)
        contentView.addSubview(balanceTextField)
        contentView.addSubview(originalBalanceTextField)
        contentView.addSubview(aprTextField)
        contentView.addSubview(minimumPaymentTextField)
        contentView.addSubview(dueDateLabel)
        contentView.addSubview(dueDatePicker)
        contentView.addSubview(saveButton)
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
        textField.rightView = createRightView()
        textField.rightViewMode = .always
        textField.delegate = self
    }
    
    private func setupTypeSegmentedControl() {
        typeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        typeSegmentedControl.insertSegment(withTitle: "Credit Card", at: 0, animated: false)
        typeSegmentedControl.insertSegment(withTitle: "Student Loan", at: 1, animated: false)
        typeSegmentedControl.insertSegment(withTitle: "Personal Loan", at: 2, animated: false)
        typeSegmentedControl.insertSegment(withTitle: "Other", at: 3, animated: false)
        typeSegmentedControl.selectedSegmentIndex = 0
        typeSegmentedControl.backgroundColor = .white
        typeSegmentedControl.selectedSegmentTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        typeSegmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor(named: "AccentLavender") ?? .darkGray
        ], for: .normal)
        typeSegmentedControl.setTitleTextAttributes([
            .foregroundColor: .white
        ], for: .selected)
        typeSegmentedControl.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
    }
    
    private func setupDueDatePicker() {
        dueDateLabel.translatesAutoresizingMaskIntoConstraints = false
        dueDateLabel.text = "Due Date"
        dueDateLabel.font = UIFont(name: "Satoshi-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        dueDateLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        dueDatePicker.translatesAutoresizingMaskIntoConstraints = false
        dueDatePicker.datePickerMode = .date
        dueDatePicker.preferredDatePickerStyle = .compact
        dueDatePicker.backgroundColor = .white
        dueDatePicker.layer.cornerRadius = 12
        dueDatePicker.layer.borderWidth = 1
        dueDatePicker.layer.borderColor = UIColor.systemGray4.cgColor
        dueDatePicker.addTarget(self, action: #selector(dueDateChanged), for: .valueChanged)
    }
    
    private func setupNavigationBar() {
        title = "Add Debt"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        navigationItem.leftBarButtonItem = cancelButton
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
            
            // Name field
            nameTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Type segmented control
            typeSegmentedControl.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 20),
            typeSegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            typeSegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            typeSegmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            // Balance fields
            balanceTextField.topAnchor.constraint(equalTo: typeSegmentedControl.bottomAnchor, constant: 20),
            balanceTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            balanceTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            balanceTextField.heightAnchor.constraint(equalToConstant: 50),
            
            originalBalanceTextField.topAnchor.constraint(equalTo: balanceTextField.bottomAnchor, constant: 16),
            originalBalanceTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            originalBalanceTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            originalBalanceTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // APR field
            aprTextField.topAnchor.constraint(equalTo: originalBalanceTextField.bottomAnchor, constant: 20),
            aprTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aprTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            aprTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Minimum payment field
            minimumPaymentTextField.topAnchor.constraint(equalTo: aprTextField.bottomAnchor, constant: 20),
            minimumPaymentTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            minimumPaymentTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            minimumPaymentTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Due date
            dueDateLabel.topAnchor.constraint(equalTo: minimumPaymentTextField.bottomAnchor, constant: 20),
            dueDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            dueDatePicker.topAnchor.constraint(equalTo: dueDateLabel.bottomAnchor, constant: 8),
            dueDatePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dueDatePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            dueDatePicker.heightAnchor.constraint(equalToConstant: 50),
            
            // Save button
            saveButton.topAnchor.constraint(equalTo: dueDatePicker.bottomAnchor, constant: 40),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
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
    
    private func createRightView() -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 50))
        return containerView
    }
    
    private func validateForm() -> Bool {
        guard let name = nameTextField.text, !name.isEmpty else {
            showAlert(title: "Error", message: "Please enter a debt name")
            return false
        }
        
        guard let balanceText = balanceTextField.text, let balance = Double(balanceText), balance > 0 else {
            showAlert(title: "Error", message: "Please enter a valid current balance")
            return false
        }
        
        guard let originalBalanceText = originalBalanceTextField.text, let originalBalance = Double(originalBalanceText), originalBalance > 0 else {
            showAlert(title: "Error", message: "Please enter a valid original balance")
            return false
        }
        
        guard let aprText = aprTextField.text, let apr = Double(aprText), apr >= 0 else {
            showAlert(title: "Error", message: "Please enter a valid APR")
            return false
        }
        
        guard let minPaymentText = minimumPaymentTextField.text, let minPayment = Double(minPaymentText), minPayment >= 0 else {
            showAlert(title: "Error", message: "Please enter a valid minimum payment")
            return false
        }
        
        return true
    }
    
    private func createDebt() -> Debt? {
        guard validateForm() else { return nil }
        
        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: selectedDueDate)
        
        return Debt(
            id: UUID().uuidString,
            userId: AuthenticationService.shared.getCurrentUser()?.id ?? "",
            name: nameTextField.text ?? "",
            type: selectedDebtType,
            currentBalance: Double(balanceTextField.text ?? "0") ?? 0,
            originalBalance: Double(originalBalanceTextField.text ?? "0") ?? 0,
            apr: Double(aprTextField.text ?? "0") ?? 0,
            minimumPayment: Double(minimumPaymentTextField.text ?? "0") ?? 0,
            dueDate: dueDay,
            accountNumber: nil,
            plaidAccountId: nil,
            isAutoSynced: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func saveTapped() {
        guard let debt = createDebt() else { return }
        
        Task {
            do {
                let savedDebt = try await FinancialDataService.shared.addDebt(debt)
                DispatchQueue.main.async {
                    self.delegate?.addDebtViewControllerDidAddDebt(savedDebt)
                    self.dismiss(animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func typeChanged() {
        let types: [Debt.DebtType] = [.creditCard, .studentLoan, .personalLoan, .other]
        selectedDebtType = types[typeSegmentedControl.selectedSegmentIndex]
    }
    
    @objc private func dueDateChanged() {
        selectedDueDate = dueDatePicker.date
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

extension AddDebtViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField:
            balanceTextField.becomeFirstResponder()
        case balanceTextField:
            originalBalanceTextField.becomeFirstResponder()
        case originalBalanceTextField:
            aprTextField.becomeFirstResponder()
        case aprTextField:
            minimumPaymentTextField.becomeFirstResponder()
        case minimumPaymentTextField:
            textField.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
