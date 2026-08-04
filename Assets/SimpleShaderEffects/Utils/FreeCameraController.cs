using UnityEngine;
using UnityEngine.InputSystem;

public class FreeCameraController : MonoBehaviour
{
    private float moveSpeed = 10f;
    private const float LookSensitivity = 0.15f;

    private float yaw;
    private float pitch;

    private void Start()
    {
        Vector3 angles = transform.eulerAngles;
        yaw = angles.y;
        pitch = angles.x;
    }

    private void Update()
    {
        if (Mouse.current == null || Keyboard.current == null)
            return;

        // Adjust movement speed with mouse wheel
        float scroll = Mouse.current.scroll.ReadValue().y;
        if (Mathf.Abs(scroll) > 0.01f)
        {
            moveSpeed *= Mathf.Pow(1.2f, scroll / 120f);
            moveSpeed = Mathf.Clamp(moveSpeed, 0.1f, 1000f);
        }

        // Rotate while holding RMB
        if (Mouse.current.rightButton.isPressed)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;

            Vector2 mouseDelta = Mouse.current.delta.ReadValue();

            yaw += mouseDelta.x * LookSensitivity;
            pitch -= mouseDelta.y * LookSensitivity;
            pitch = Mathf.Clamp(pitch, -89f, 89f);

            transform.rotation = Quaternion.Euler(pitch, yaw, 0f);
        }
        else
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        float speed = moveSpeed;

        if (Keyboard.current.leftShiftKey.isPressed || Keyboard.current.rightShiftKey.isPressed)
            speed *= 5f;

        Vector3 movement = Vector3.zero;

        if (Keyboard.current.wKey.isPressed)
            movement += transform.forward;

        if (Keyboard.current.sKey.isPressed)
            movement -= transform.forward;

        if (Keyboard.current.dKey.isPressed)
            movement += transform.right;

        if (Keyboard.current.aKey.isPressed)
            movement -= transform.right;

        if (Keyboard.current.eKey.isPressed)
            movement += transform.up;

        if (Keyboard.current.qKey.isPressed)
            movement -= transform.up;

        if (movement.sqrMagnitude > 1f)
            movement.Normalize();

        transform.position += movement * speed * Time.unscaledDeltaTime;
    }
}