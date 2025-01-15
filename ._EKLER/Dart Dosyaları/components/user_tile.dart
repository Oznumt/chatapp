import "package:flutter/material.dart";

class UserTile extends StatelessWidget {
  final String text;
  final void Function()? onTap;
  final Widget? leading;

  const UserTile({
    super.key,
    required this.text,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 20),
            Text(text),
          ],
        ),
      ),
    );
  }
}
