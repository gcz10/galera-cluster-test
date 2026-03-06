.PHONY: validate fmt-check ansible-syntax terraform-validate

validate: fmt-check ansible-syntax

fmt-check:
	terraform fmt -check -recursive

ansible-syntax:
	cd galera/ansible && ansible-playbook site.yml --syntax-check

terraform-validate:
	@echo "Run 'terraform init' in each Terraform root before this target."
	terraform validate
	cd galera/terraform && terraform validate
	cd galera-dev/terraform && terraform validate
