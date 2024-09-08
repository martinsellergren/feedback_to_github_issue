import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:feedback/feedback.dart';
import 'package:feedback_to_github_issue/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:provider/provider.dart';

class FeedbackInput extends StatelessWidget {
  final String githubRepositoryOwner;
  final String githubRepositoryName;
  final String defaultGithubAccessToken;
  final String defaultGithubAccessTokenOwner;
  final Widget child;

  const FeedbackInput(
      {super.key,
      required this.defaultGithubAccessToken,
      required this.child,
      required this.githubRepositoryOwner,
      required this.githubRepositoryName,
      required this.defaultGithubAccessTokenOwner});

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: _Params(
        githubRepositoryOwner: githubRepositoryOwner,
        githubRepositoryName: githubRepositoryName,
        defaultGithubAccessToken: defaultGithubAccessToken,
        defaultGithubAccessTokenOwner: defaultGithubAccessTokenOwner,
      ),
      child: ChangeNotifierProvider(
        create: (context) => _SubmitErrorMessageState(),
        child: BetterFeedback(
          theme: FeedbackThemeData(
            sheetIsDraggable: false,
          ),
          feedbackBuilder: (context, onSubmit, scrollController) =>
              _Builder(onSubmit: onSubmit),
          child: child,
        ),
      ),
    );
  }

  static void show(BuildContext context) {
    final params = context.params;
    final errState = context.read<_SubmitErrorMessageState>();
    BetterFeedback.of(context).show(
      (userFeedback) => _submitFeedback(
        defaultGithubAccessToken: params.defaultGithubAccessToken,
        githubRepositoryName: params.githubRepositoryName,
        githubRepositoryOwner: params.githubRepositoryOwner,
        feedback: userFeedback,
        onError: (e) => errState.value = e,
      ),
    );
  }
}

class _Params {
  final String githubRepositoryOwner;
  final String githubRepositoryName;
  final String defaultGithubAccessToken;
  final String defaultGithubAccessTokenOwner;

  _Params(
      {required this.githubRepositoryOwner,
      required this.githubRepositoryName,
      required this.defaultGithubAccessToken,
      required this.defaultGithubAccessTokenOwner});
}

class _SubmitErrorMessageState extends ValueNotifier<Object?> {
  _SubmitErrorMessageState() : super(null);
}

extension on BuildContext {
  _Params get params => read();
  String? get submitErrorMessage =>
      watch<_SubmitErrorMessageState>().value?.toString();
}

class _Builder extends StatefulWidget {
  final OnSubmit onSubmit;

  const _Builder({required this.onSubmit});

  @override
  State<_Builder> createState() => _BuilderState();
}

class _BuilderState extends State<_Builder> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _includeScreenshotKey = GlobalKey<_IncludeScreenshotToggleState>();

  @override
  Widget build(BuildContext context) {
    final submitErrorMessage = context.submitErrorMessage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Title(),
        _TitleInput(textEditingController: _titleController),
        _DescriptionInput(textEditingController: _descriptionController),
        _GithubAccessTokenInput(
          textEditingController: _accessTokenController,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _IncludeScreenshotToggle(key: _includeScreenshotKey),
        ),
        if (submitErrorMessage != null)
          Center(
            child: Text(
              submitErrorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Center(
          child: ListenableBuilder(
            listenable: _titleController,
            builder: (context, child) => _Submit(
              isEnabled: _titleController.text.isNotEmpty,
              title: () => _titleController.text,
              description: () => _descriptionController.text,
              githubAccessToken: () => _accessTokenController.text,
              includeScreenshot: () =>
                  _includeScreenshotKey.currentState?.isSelected ?? true,
              onSubmit: widget.onSubmit,
            ),
          ),
        ),
      ]
          .map((e) => Padding(
                padding: const EdgeInsets.all(4.0),
                child: e,
              ))
          .toList(),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Create a new github issue',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _TitleInput extends StatelessWidget {
  final TextEditingController textEditingController;

  const _TitleInput({required this.textEditingController});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Title',
      ),
      controller: textEditingController,
      maxLines: 1,
      textInputAction: TextInputAction.next,
    );
  }
}

class _DescriptionInput extends StatelessWidget {
  final TextEditingController textEditingController;

  const _DescriptionInput({required this.textEditingController});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Description',
      ),
      controller: textEditingController,
      maxLines: null,
    );
  }
}

class _IncludeScreenshotToggle extends StatefulWidget {
  const _IncludeScreenshotToggle({super.key});

  @override
  State<_IncludeScreenshotToggle> createState() =>
      _IncludeScreenshotToggleState();
}

class _IncludeScreenshotToggleState extends State<_IncludeScreenshotToggle> {
  bool isSelected = true;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: const Text('Include screenshot in issue'),
      selected: isSelected,
      onSelected: (value) => setState(() => isSelected = value),
    );
  }
}

class _GithubAccessTokenInput extends StatelessWidget {
  final TextEditingController textEditingController;

  const _GithubAccessTokenInput({required this.textEditingController});

  @override
  Widget build(BuildContext context) {
    final params = context.params;
    return TextField(
      decoration: InputDecoration(
        labelText: 'Personal github access token',
        helperText:
            'Determines the author of this issue. If you leave it empty, the author is ${params.defaultGithubAccessTokenOwner}.',
      ),
      controller: textEditingController,
      maxLines: 1,
      textInputAction: TextInputAction.next,
    );
  }
}

class _Submit extends StatefulWidget {
  final String Function() title;
  final String Function() description;
  final String Function() githubAccessToken;
  final bool Function() includeScreenshot;
  final OnSubmit onSubmit;
  final bool isEnabled;

  const _Submit(
      {required this.title,
      required this.description,
      required this.githubAccessToken,
      required this.includeScreenshot,
      required this.onSubmit,
      required this.isEnabled});

  @override
  State<_Submit> createState() => _SubmitState();
}

class _SubmitState extends State<_Submit> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return _isSubmitting
        ? const Text('submitting...')
        : TextButton(
            onPressed: !widget.isEnabled
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    await widget.onSubmit(
                      widget.description(),
                      extras: {
                        _titleKey: widget.title(),
                        _githubAccessTokenKey: widget.githubAccessToken(),
                        _includeScreenshotKey: widget.includeScreenshot(),
                      },
                    );
                    if (mounted) setState(() => _isSubmitting = false);
                  },
            child: const Text('Submit'),
          );
  }
}

const _titleKey = 'title';
const _githubAccessTokenKey = 'githubAccessToken';
const _includeScreenshotKey = 'includeScreenshot';

Future<void> _submitFeedback({
  required String githubRepositoryOwner,
  required String githubRepositoryName,
  required String defaultGithubAccessToken,
  required UserFeedback feedback,
  required Function(Object? e) onError,
}) async {
  try {
    final title = (feedback.extra![_titleKey]! as String).nullIfEmpty!;
    final description = feedback.text;
    final githubAccessToken =
        (feedback.extra![_githubAccessTokenKey] as String).nullIfEmpty;
    final includeScreenshot = feedback.extra![_includeScreenshotKey] as bool;
    log('Submit feedback title=$title, description=$description');

    final github = GitHub(
      auth: Authentication.withToken(
        githubAccessToken ?? defaultGithubAccessToken,
      ),
    );
    final repo = await github.repositories.getRepository(
        RepositorySlug(githubRepositoryOwner, githubRepositoryName));
    final screenshotUrl = !includeScreenshot
        ? null
        : await _screenshotUrl(
            github: github,
            repoSlug: repo.slug(),
            screenshot: feedback.screenshot,
            issueTitle: title,
          );
    await github.issues.create(
      repo.slug(),
      IssueRequest(
        title: title,
        body: [
          description,
          if (screenshotUrl != null) screenshotUrl,
        ].join('\n\n'),
      ),
    );
  } catch (e, s) {
    log('Error submitting feedback', error: e, stackTrace: s);
    onError(e);
    throw SubmitFeedbackException(); // throwing ensures the dialog isn't closed
  }
}

class SubmitFeedbackException implements Exception {}

Future<String> _screenshotUrl({
  required GitHub github,
  required RepositorySlug repoSlug,
  required String issueTitle,
  required Uint8List screenshot,
}) async {
  final fileName = '${issueTitle}_${DateTime.now().microsecondsSinceEpoch}.png';
  final res = await github.repositories.createFile(
      repoSlug,
      CreateFile(
        branch: 'issue-images',
        message: 'screenshot for issue: $issueTitle',
        path: fileName,
        content: base64.encode(screenshot),
      ));
  if (res.content == null) throw 'Error when creating screenshot url';
  return '![screenshot](../blob/issue-images/$fileName?raw=true)';
}
