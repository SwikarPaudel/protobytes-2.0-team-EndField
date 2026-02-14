import uvicorn
# programmatically start and configure a web server directly from  script


def main():
    print("=" * 60)
    print("  CodeQuest Backend Server")
    print("  http://127.0.0.1:8000/")
    print("  API docs: http://127.0.0.1:8000/docs")
    print("=" * 60)
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )


if __name__ == "__main__":
    main()
