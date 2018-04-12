resource "aws_iam_group" "webops" {
  name = "WebOps"
}

resource "aws_iam_group" "developers" {
  name = "Developers"
}

data "external" "vault" {
    program = ["python3", "../get-users.py"]
    query {
        vault = "${var.vault-name}"
        aws_users_webops = "users-webops"
        aws_users_developers = "users-developers"
    }
}

locals {
aws_users_webops = "${compact(split(",",data.external.vault.result.aws_users_webops))}"
aws_users_developers = "${compact(split(",",data.external.vault.result.aws_users_developers))}"

}

resource "aws_iam_user" "user" {
  count = "${length(local.aws_users_webops)}"
  name = "${element(local.aws_users_webops, count.index)}"
}

resource "aws_iam_user" "user-developer" {
  count = "${length(local.aws_users_developers)}"
  name = "${element(local.aws_users_developers, count.index)}"
}

resource "aws_iam_group_membership" "webops_group_membership" {
  name = "webops-group-membership"
  users = ["${aws_iam_user.user.*.name}"]
  group = "${aws_iam_group.webops.name}"

  depends_on = ["aws_iam_user.user"]
}

resource "aws_iam_group_membership" "developers_group_membership" {
  name = "developers-group-membership"
  users = ["${aws_iam_user.user-developer.*.name}"]
  group = "${aws_iam_group.developers.name}"

  depends_on = ["aws_iam_user.user-developer"]
}

locals {
all_users = "${concat(local.aws_users_webops,local.aws_users_developers)}"
}

resource "aws_iam_user_login_profile" "user" {
  count = "${length(local.all_users)}"
  user    = "${element(local.all_users, count.index)}"
  pgp_key = "${file("~/my-public-key.asc")}"
  password_length = 14
}

output "password" {
  sensitive = true
  value = "${zipmap(local.all_users,aws_iam_user_login_profile.user.*.encrypted_password)}"

  depends_on = ["aws_iam_user_login_profile.user"]
}

resource "aws_iam_policy" "enable-mfa" {
  name        = "enable-mfa"
  description = "Enable MFA on user accounts"
  policy      = "${file("../policies/enable-mfa-policy.json")}"
}

resource "aws_iam_group_policy_attachment" "webops-attach-enable-mfa" {
  group      = "${aws_iam_group.webops.name}"
  policy_arn = "${aws_iam_policy.enable-mfa.arn}"

  depends_on = ["aws_iam_policy.enable-mfa"]
}

resource "aws_iam_group_policy_attachment" "developers-attach-enable-mfa" {
  group      = "${aws_iam_group.developers.name}"
  policy_arn = "${aws_iam_policy.enable-mfa.arn}"

  depends_on = ["aws_iam_policy.enable-mfa"]
}

resource "aws_iam_group_policy_attachment" "webops-attach-iam-password-change" {
  group      = "${aws_iam_group.webops.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"

  depends_on =["aws_iam_group.webops"]
}

resource "aws_iam_group_policy_attachment" "developers-attach-iam-password-change" {
  group      = "${aws_iam_group.developers.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"

  depends_on =["aws_iam_group.developers"]
}

resource "aws_iam_group_policy_attachment" "webops-attach-administrator-access" {
  group      = "${aws_iam_group.webops.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  depends_on =["aws_iam_group.webops"]
}