import UIKit

class PopupViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    // 弹出视图的容器
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // 标题
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    //说明
    private let remarkLabel: UILabel = {
        let label = UILabel()
        label.text = "观察舵机当前位置，如若未居中请调整偏移角度，使舵机位置居中"
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textAlignment = .center
        label.textColor = .gray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // PickerView
    let pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    // 取消按钮
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.tintColor = .black
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 1
        return button
    }()

    // 确定按钮
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("确定", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .black
        button.tintColor = .white
        button.layer.cornerRadius = 8
        return button
    }()

    // 按钮容器
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 30
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // let data = Array(stride(from: 30, through: 0, by: -1))
    let data = Array(stride(from: 20, through: -20, by: -1))
    var row = 0
    var reviseInfo: ReviseInfo!
    var onReviseOffsetBlock: ((_ offset: NSNumber) -> Void)!

    override func viewDidLoad() {
        super.viewDidLoad()
        pickerView.dataSource = self
        pickerView.delegate = self
        titleLabel.text = reviseInfo.title
        if let index = data.firstIndex(of: Int(reviseInfo.offset)) {
            row = index
        }
        pickerView.selectRow(row, inComponent: 0, animated: false)
        setupView()
    }

    private func setupView() {
        // 设置半透明背景
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // 添加容器视图
        view.addSubview(containerView)

        // 容器视图约束 (宽300 高400)
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
        ])

        // 添加标题
        containerView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -20),
        ])

        // 添加说明
        containerView.addSubview(remarkLabel)
        NSLayoutConstraint.activate([
            remarkLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            remarkLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 20),
            remarkLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -20),
        ])

        // 添加PickerView
        containerView.addSubview(pickerView)
        NSLayoutConstraint.activate([
            pickerView.topAnchor.constraint(equalTo: remarkLabel.bottomAnchor, constant: 8),
            pickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            pickerView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -20),
            pickerView.heightAnchor.constraint(equalToConstant: 150),
        ])

        // 添加按钮容器
        containerView.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(confirmButton)

        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: pickerView.bottomAnchor, constant: 8),
            buttonStackView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44),
        ])

        // 添加按钮动作
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
    }

    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func confirmButtonTapped() {
        // 在这里处理确定按钮的逻辑
        onReviseOffsetBlock(data[row] as NSNumber)
        dismiss(animated: true, completion: nil)
    }

    // 返回 pickerView 的列数
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    // 自定义行高
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 50
    }

    // 返回每列的行数
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return data.count
    }

    // MARK: - UIPickerViewDelegate

    // 返回每行的标题
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
        -> String?
    {
        return String(format: "%d°", data[row])
    }

    // 选中某行后的回调
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.row = row
    }

}
