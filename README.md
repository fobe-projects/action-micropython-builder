# action-micropython-builder

## Introduction

`action-micropython-builder` is a GitHub Action designed to build MicroPython ports. It supports multiple platforms and boards, enabling developers to quickly build MicroPython projects.

## Features

- Supports multiple MicroPython platforms (e.g., esp32, nrf).
- Allows specifying custom repository remote and reference.
- Supports building specific boards.

## Usage

### 1. Reference in Workflow

Add the following to your GitHub Actions workflow file:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython
        uses: fobe-projects/action-micropython-builder@v1
        with:
          port: "esp32"
          board: "FOBE_QUILL_ESP32S3_MESH"
```

### 2. Input Parameters

| Parameter Name  | Required | Default  | Description                                   |
|-----------------|----------|----------|-----------------------------------------------|
| `repo_remote`   | No       | `origin` | The MicroPython repository remote ('origin', 'upstream'). |
| `repo_ref`      | No       | `main`   | The MicroPython repository reference (branch, tag, commit). |
| `port`          | Yes      | None     | The MicroPython platform to build (esp32, nrf). |
| `board`         | No       | `""`     | The MicroPython board to build. |

### 3. Examples

#### Build a Single Board

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython for ESP32
        uses: fobe-projects/action-micropython-builder@v1
        with:
          port: "esp32"
          board: "FOBE_QUILL_ESP32S3_MESH"
```

#### Build with Custom Repository Reference

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython from specific branch
        uses: fobe-projects/action-micropython-builder@v1
        with:
          repo_remote: "upstream"
          repo_ref: "v1.20.0"
          port: "nrf"
          board: "pca10040"
```

#### Build without Specifying Board

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython for ESP32 platform
        uses: fobe-projects/action-micropython-builder@v1
        with:
          port: "esp32"
```

## License

This project is licensed under the MIT License. For details, see [LICENSE](./LICENSE).
