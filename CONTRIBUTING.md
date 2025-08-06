# 🤝 Contribuir al Proyecto

¡Gracias por tu interés en contribuir!

Este proyecto sigue buenas prácticas de Terraform, CI/CD y documentación automatizada.

---

## 🧱 Requisitos

- Terraform ≥ 1.3
- AWS CLI configurado (SSO o Access Keys)
- Python ≥ 3.8
- Herramientas instaladas:
  - `pre-commit`
  - `tflint`
  - `checkov`
  - `terraform-docs`

---

## 🚀 Flujo de trabajo recomendado

1. Haz un fork del repositorio
2. Crea una nueva rama: `git checkout -b feature/nombre`
3. Realiza tus cambios
4. Asegúrate de pasar todos los hooks:
   ```bash
   pre-commit run --all-files
   ```
5. Actualiza el `CHANGELOG.md` si corresponde
6. Haz un PR a `main`

---

## 📋 Formato de commits sugerido

- `feat: añade nueva funcionalidad`
- `fix: corrige un bug`
- `docs: actualiza documentación`
- `chore: tareas menores`

---

## ✅ Buenas prácticas

- Usa nombres descriptivos para los recursos
- Mantén los archivos `.tf` organizados por dominio (network, compute, etc.)
- Sigue el estándar HCL para estilo y orden

¡Gracias por hacer este proyecto mejor! 🙌
