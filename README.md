# action-micropython-builder

## Introduction

`action-micropython-builder` is a GitHub Action designed to build MicroPython ports. It supports multiple platforms and targets, enabling developers to quickly build and release MicroPython projects.

## Features

- Supports multiple MicroPython platforms (e.g., espressif, nordic).
- Supports build and release targets.
- Allows specifying single or multiple boards for building.

## Usage

### 1. Reference in Workflow

Add the following to your GitHub Actions workflow file:

```yaml
yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython
        uses: fobe-projects/action-micropython-builder@v1
        with:
          mpy_platform: "espressif" # Required, specify the platform
          mpy_target: "build"       # Optional, defaults to build
          mpy_board: "esp32"        # Required when mpy_target is build
```

### 2. Input Parameters

| Parameter Name  | Required | Default  | Description                                   |
|-----------------|----------|----------|-----------------------------------------------|
| `mpy_platform`  | Yes      | None     | MicroPython platform (e.g., espressif, nordic). |
| `mpy_target`    | No       | `build`  | Target to run, options are `build` or `release`.   |
| `mpy_board`     | No       | None     | Required when `mpy_target` is `build`, specify the board. |
| `mpy_boards`    | No       | None     | Required when `mpy_target` is `release`, specify multiple boards. |

### 3. Examples

#### Build a Single Board

```yaml
yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build MicroPython for ESP32
        uses: fobe-projects/action-micropython-builder@v1
        with:
          mpy_platform: "espressif"
          mpy_target: "build"
          mpy_board: "esp32"
```

#### Release Multiple Boards

```yaml
yaml
jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Release MicroPython for multiple boards
        uses: fobe-projects/action-micropython-builder@v1
        with:
          mpy_platform: "nordic"
          mpy_target: "release"
          mpy_boards: "board1,board2,board3"
```

## Notes

- When `mpy_target` is `build`, the `mpy_board` parameter must be provided.
- When `mpy_target` is `release`, the `mpy_boards` parameter must be provided.

## License

This project is licensed under the MIT License. For details, see [LICENSE](./LICENSE).
