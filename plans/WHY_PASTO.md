# Why You Should Try Pasto

Or: How I Learned to Stop Worrying and Love Self-Hosted Pastebins

## The Problem Nobody Talks About

Let me tell you about a problem you probably have but don't think about: where do you put code snippets you want to share?

If you're like most developers, you probably use one of the big public pastebins. Maybe pastebin.com, GitHub Gists, or whatever else shows up first in Google. And they're... fine. They work. Until they don't.

Here's what bugs me about them:

**They read your pastes.** Yeah, I know, "if you're not paying, you're the product." But sometimes I'm sharing actual secrets. API keys I need to show a coworker. A config file with sensitive data. Debug output with customer information. You get the idea. I don't love the idea that some company's servers can read all of that.

**They disappear.** Remember when Pastebin started blocking entire countries? Or when Gist goes down and takes your shared snippets with it? Or worse, when these services just... shut down? (RIP like a dozen code sharing sites I've used over the years.)

**They're slower than they should be.** I don't need fancy features. I need to paste code and get a link. Fast. Not after loading three analytics scripts and a GDPR banner.

**SSH access basically doesn't exist.** Look, sometimes I'm already in a terminal. I don't want to open a browser, paste my code, fight with the UI, copy the URL, and come back. I want to pipe some text to SSH and get a link. 

Apparently, this *is* too much to ask. Out of dozens of pastebin services, exactly two have SSH interfaces: snips.sh and Pasto. That's it. Everyone else acts like the terminal doesn't exist.

## What Pasto Actually Does

Pasto is my answer to these problems. It's a pastebin you run yourself, on your own server. Or on a cheap VPS. Or even on your laptop if you just want it for your local network.

Here's what makes it different:

### It Actually Has End-to-End Encryption

Not "we encrypt your data at rest" (which just means they can still read it). Real encryption. The browser encrypts your paste before sending it to the server. The server stores an encrypted blob it can't read. When someone views it, their browser decrypts it.

Is this overkill for most code snippets? Probably. But when you need it, you *really* need it.

### It Actually Has an SSH Interface

Here's a wild idea: what if you could use a pastebin from the terminal without curling URLs and parsing JSON?

```bash
cat myfile.py | ssh pasto.example.com
```

That's it. You get back a URL. No web browser required. No API tokens to configure. Just SSH.

Want options?

```bash
cat script.py | ssh pasto.example.com paste -l python -t "My Script" --expire 1h --encrypted
```

Need to see your pastes?

```bash
ssh pasto.example.com list
```

Want to edit one?

```bash
cat updated.py | ssh pasto.example.com edit abc123
```

Delete it?

```bash
ssh pasto.example.com delete abc123
```

There are 13 commands total. They all work from the terminal. They're all scriptable. They all use the same SSH key you're already using for everything else.

This is apparently such a radical concept that only one other pastebin (snips.sh) bothers to do it. I don't understand why. It's not that hard, and it makes the whole experience so much better if you live in the terminal.

### It's Fast

Pasto is written in Crystal, which compiles to native code. It's fast. The syntax highlighting (all 321 themes of it, thanks to Tartrazine) happens on the server, so the browser just renders HTML. No huge JavaScript bundles to download.

Also, it's *your* server. No sharing resources with thousands of other users. No rate limiting that kicks in right when you need it.

### It Has Features You Didn't Know You Wanted

- **Burn after reading** - Paste deletes itself after being viewed once. Great for sharing passwords or API keys.
- **Custom expiration** - 10 minutes, 1 hour, 1 day, whenever. Or never, if you want.
- **Private pastes** - Only visible to you when logged in.
- **321+ syntax themes** - Because why not? Find one you like.
- **Markdown rendering** - Toggle between source and rendered view. Nice for docs.
- **API access** - Full REST API with key-based auth. Automate everything.
- **Actually works on mobile** - Responsive design that doesn't suck.

## The Catch

There's always a catch, right? Here it is: you have to run it yourself.

Now, before you close this tab, hear me out. Running Pasto is stupid simple:

```bash
git clone https://github.com/ralsina/pasto.git
cd pasto
shards build
./bin/pasto
```

That's it. It runs on port 3000. No database to configure (it uses filesystem storage via Sepia). No complex setup. No environment variables you *must* set (though there are options if you want them).

Want to run it in production? Same thing, but maybe put it behind nginx or caddy for HTTPS. There's a Docker image if that's your thing. The whole binary is like 10MB.

Is this more work than using pastebin.com? Yes. Obviously. But it's like 10 minutes of work, once, and then you have your own pastebin that you control forever.

## Who Is This For?

Honestly? I built Pasto for me. But it might be for you if:

- You're tired of wondering if your pastebin is reading your code
- You want SSH access that doesn't feel like an afterthought
- You run other self-hosted stuff and this fits right in
- You're in a corporate environment where using public pastebins is... frowned upon
- You just like having control over your tools

It's definitely overkill if you're just sharing "Hello World" examples on Stack Overflow. But if you're sharing anything remotely sensitive, or you live in the terminal, or you just like having your own infrastructure? Give it a shot.

## Try It

There's a public instance at [pasto1.ralsina.me](https://pasto1.ralsina.me) if you want to kick the tires. Obviously don't put anything actually secret there without encryption, because I can read it (and so can anyone else who guesses the URL).

For real use, though, run your own. The code is on [GitHub](https://github.com/ralsina/pasto). MIT licensed. Do whatever you want with it.

And if you find bugs or have ideas? PRs welcome. Or just open an issue. Or don't. I built this for me, but I'm happy if it helps other people too.

---

Roberto Alsina  
December 2025  

P.S. - Yes, I know there are other self-hosted pastebins. I tried most of them. They either didn't have encryption, or the SSH interface was bad, or they required a database, or they just didn't work the way I wanted. So I built my own. Classic developer move, I know.
